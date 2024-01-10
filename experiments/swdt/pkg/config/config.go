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

package config

import (
	"fmt"
	"os"

	"swdt/apis/config/v1alpha1"

	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/serializer"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
)

var (
	scheme = runtime.NewScheme()
	codecs = serializer.NewCodecFactory(scheme, serializer.EnableStrict)
)

func init() {
	utilruntime.Must(v1alpha1.AddToScheme(scheme))
}

// LoadConfigFromFile returns the marshalled Configuration object
func LoadConfigFromFile(file string) (*v1alpha1.Config, error) {
	data, err := os.ReadFile(file)
	if err != nil {
		return nil, err
	}
	return loadConfig(data)
}

// loadConfig decode the input read YAML into a configuration object
func loadConfig(data []byte) (*v1alpha1.Config, error) {
	var deserializer = codecs.UniversalDeserializer()
	configObj, gvk, err := deserializer.Decode(data, nil, nil)
	if err != nil {
		return nil, err
	}
	config, ok := configObj.(*v1alpha1.Config)
	if !ok {
		return nil, fmt.Errorf("got unexpected config type: %v", gvk)
	}
	return config, nil
}
