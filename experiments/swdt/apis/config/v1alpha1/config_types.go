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

package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type DeploySpec struct {
	// Name of the service to be deployed
	Name string `json:"name,omitempty"`

	// Version is the binary version to be deployed
	Version string `json:"version,omitempty"`

	// SourceURL set the HTTP server to be downloaded from
	SourceURL string `json:"sourceURL,omitempty"`

	// Destination set the Windows patch to upload the file
	Destination string `json:"destination,omitempty"`

	// Overwrite delete the old file if exists first.
	Overwrite bool `json:"overwrite,omitempty"`
}

type KubernetesSpec struct {
	// Deploys list the objects to be deployed
	Deploys []DeploySpec `json:"deploys"`
}

type CredentialsSpec struct {
	// Username set the Windows user
	Username string `json:"username,omitempty"`

	// Hostname set the Windows node endpoint
	Hostname string `json:"hostname,omitempty"`

	// PrivateKey is the SSH private path for this user
	PrivateKey string `json:"publicKey,omitempty"`
}

type SetupSpec struct {
	// EnableRDP set up the remote desktop service and enable firewall for it.
	EnableRDP *bool `json:"enableRDP"`

	// ChocoPackages provides a list of packages automatically installed in the node.
	ChocoPackages *[]string `json:"chocoPackages,omitempty"`
}

// ConfigSpec defines the desired state of Config
type ConfigSpec struct {
	Cred       CredentialsSpec `json:"credentials,omitempty"`
	Setup      SetupSpec       `json:"setup,omitempty"`
	Kubernetes KubernetesSpec  `json:"kubernetes,omitempty"`
}

// ConfigStatus -- tbd
type ConfigStatus struct {
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status
//+k8s:defaulter-gen=true

// Config is the Schema for the configs API
type Config struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   ConfigSpec   `json:"spec,omitempty"`
	Status ConfigStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// ConfigList contains a list of Config
type ConfigList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Config `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Config{}, &ConfigList{})
}
