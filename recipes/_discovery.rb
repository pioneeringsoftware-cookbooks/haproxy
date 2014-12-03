#
# Cookbook Name:: haproxy
# Recipe:: _discovery
#
# Copyright 2011, Heavy Water Operations, LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

pool_members = search("node", "role:#{node['haproxy']['app_server_role']} AND chef_environment:#{node.chef_environment}") || []

# load balancer may be in the pool
pool_members << node if node.run_list.roles.include?(node['haproxy']['app_server_role'])

# we prefer connecting via local_ipv4 if
# pool members are in the same cloud
# TODO refactor this logic into library...see COOK-494
pool_members.map! do |member|
  server_ip = begin
    # Do not use `member.attribute?('cloud')` to determine if the prospective
    # pool member has cloud attributes. The Ohai cloud plugin sets up the cloud
    # mash albeit with empty address arrays even if the member is not a
    # cloud-based node. In other words, `attribute?('cloud')` always answers
    # true and therefore redundant. Instead, decide if the cloud hash is empty,
    # or not.
    if member['cloud'].values.flatten.empty?
      if node['cloud'].values.flatten.empty? && (member['cloud']['provider'] == node['cloud']['provider'])
         member['cloud']['local_ipv4']
      else
        member['cloud']['public_ipv4']
      end
    else
      member['ipaddress']
    end
  end
  {:ipaddress => server_ip, :hostname => member['hostname']}
end

pool_members.sort! do |a,b|
  a[:hostname].downcase <=> b[:hostname].downcase
end

node.set['haproxy']['pool_members'] = pool_members || {}
