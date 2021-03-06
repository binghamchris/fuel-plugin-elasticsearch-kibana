#    Copyright 2015 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
#
$elasticsearch_kibana = hiera('elasticsearch_kibana')

# Params related to Elasticsearch.
$es_dir       = $elasticsearch_kibana['data_dir']
$es_instance  = 'es-01'
$es_heap_size = $elasticsearch_kibana['jvm_heap_size']

# Java
$java = $::operatingsystem ? {
  CentOS => 'java-1.8.0-openjdk-headless',
  Ubuntu => 'openjdk-7-jre-headless'
}

# Ensure that java is installed
package { $java:
  ensure => installed,
}

file { $es_dir:
  ensure => 'directory',
}

# Install elasticsearch
class { 'elasticsearch':
  datadir       => ["${es_dir}/elasticsearch_data"],
  init_defaults => {
      'MAX_LOCKED_MEMORY' => 'unlimited',
      'ES_HEAP_SIZE'      => "${es_heap_size}g"
  },
  require       => [File[$es_dir], Package[$java]],
}

# Start an instance of elasticsearch
elasticsearch::instance { $es_instance:
  config => {
    'threadpool.bulk.queue_size' => '1000',
    'bootstrap.mlockall'         => true,
    'http.cors.allow-origin'     => '/.*/',
    'http.cors.enabled'          => true
  },
}

lma_logging_analytics::es_template { ['log', 'notification']:
  number_of_replicas => 0 + $elasticsearch_kibana['number_of_replicas'],
  require            => Elasticsearch::Instance[$es_instance],
}

class { 'lma_logging_analytics::curator':
  retention_period => $elasticsearch_kibana['retention_period'],
  prefixes         => ['log', 'notification'],
}
