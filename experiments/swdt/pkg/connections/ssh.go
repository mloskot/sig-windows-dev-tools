/*
Copyright 2024 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package connections

import (
	"bytes"
	"errors"
	"fmt"
	scp "github.com/bramvdbogaerde/go-scp"
	"golang.org/x/crypto/ssh"
	"io"
	"os"
	"path"
	"swdt/apis/config/v1alpha1"
	"sync"
)

const (
	TCP_TYPE   = "tcp"
	SCP_BINARY = "C:\\Windows\\System32\\OpenSSH\\scp.exe"
)

type SSHConnection struct {
	credentials *v1alpha1.CredentialsSpec
	password    string
	client      *ssh.Client
}

func (c *SSHConnection) Connect() error {
	client, err := ssh.Dial(TCP_TYPE, c.credentials.Hostname, &ssh.ClientConfig{
		User:            c.credentials.Username,
		Auth:            []ssh.AuthMethod{ssh.Password(c.password)},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
	})
	if err != nil {
		return fmt.Errorf("failed to dial: %s", err)
	}
	c.client = client
	return nil
}

func (c *SSHConnection) Run(args string) (string, error) {
	if c.client == nil {
		return "", fmt.Errorf("client is empty, call Connect() first")
	}

	var (
		err     error
		session *ssh.Session
		b       bytes.Buffer
	)
	if session, err = c.client.NewSession(); err != nil {
		return "", err
	}
	defer session.Close()
	session.Stdout = &b
	if err := session.Run("powershell -c " + args); err != nil {
		return "", err
	}

	return b.String(), nil
}

func (c *SSHConnection) Copy(local, remote, perm string) error {
	file, err := os.Open(local)
	if err != nil {
		return err
	}
	var contents []byte
	contents, err = io.ReadAll(file)
	if err != nil {
		return fmt.Errorf("failed to read all data from reader: %w", err)
	}
	return c.CopyPassThru(bytes.NewReader(contents), remote, perm, int64(len(contents)))
}

func (c *SSHConnection) CopyPassThru(reader io.Reader, remote string, permissions string, size int64) error {
	var filename = path.Base(remote)

	session, err := c.client.NewSession()
	if err != nil {
		return err
	}
	defer session.Close()

	stdout, err := session.StdoutPipe()
	if err != nil {
		return err
	}
	writer, err := session.StdinPipe()
	if err != nil {
		return err
	}
	defer writer.Close()

	wg := sync.WaitGroup{}
	wg.Add(2)

	errCh := make(chan error, 1)

	go func() {
		defer wg.Done()
		defer writer.Close()
		_, err = fmt.Fprintln(writer, "C"+permissions, size, filename)
		if err != nil {
			errCh <- err
			return
		}

		if err = checkResponse(stdout); err != nil {
			errCh <- err
			return
		}
		_, err = io.Copy(writer, reader)
		if err != nil {
			errCh <- err
			return
		}

		_, err = fmt.Fprint(writer, "\x00")
		if err != nil {
			errCh <- err
			return
		}
		if err = checkResponse(stdout); err != nil {
			errCh <- err
			return
		}
	}()

	go func() {
		defer wg.Done()
		err := session.Start(fmt.Sprintf("%s -qt %q", SCP_BINARY, remote))
		if err != nil {
			errCh <- err
			return
		}
	}()

	wg.Wait()
	close(errCh)
	for err := range errCh {
		if err != nil {
			return err
		}
	}
	return nil
}

func (c *SSHConnection) Close() error {
	if c.client == nil {
		return nil
	}
	return c.client.Close()
}

func checkResponse(r io.Reader) error {
	response, err := scp.ParseResponse(r)
	if err != nil {
		return err
	}
	if response.IsFailure() {
		return errors.New(response.GetMessage())
	}
	return nil
}
