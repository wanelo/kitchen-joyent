# Encoding: utf-8
#
# Author:: Sean OMeara (<someara@gmail.com>)
#
# Copyright (C) 2013, Sean OMeara
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'benchmark'
require 'fog'
require 'kitchen'
require 'etc'
require 'socket'

module Kitchen
  module Driver
    # Joyent driver for Kitchen.
    #
    # @author Sean OMerara <someara@gmail.com>
    class Joyent < Kitchen::Driver::SSHBase
      default_config :joyent_url, 'https://us-sw-1.api.joyentcloud.com'
      default_config :joyent_image_id, '87b9f4ac-5385-11e3-a304-fb868b82fe10'
      default_config :joyent_flavor_id, 'g3-standard-4-smartos'
      default_config :username, 'root'
      default_config :port, '22'
      default_config :sudo, false

      def create(state)
        server = create_server
        state[:server_id] = server.id
        info("Joyent <#{state[:server_id]}> created.")
        server.wait_for { print '.'; ready? }

        print '(server ready)'
        state[:hostname] = server.public_ip_address
        wait_for_sshd(state[:hostname])
        print "(ssh ready)\n"
        debug("joyent:create #{state[:hostname]}")
      rescue Fog::Errors::Error, Excon::Errors::Error => ex
        raise ActionFailed, ex.message
      end

      def destroy(state)
        return if state[:server_id].nil?

        server = compute.servers.get(state[:server_id])
        server.destroy unless server.nil?
        info("Joyent instance <#{state[:server_id]}> destroyed.")
        state.delete(:server_id)
        state.delete(:hostname)
      end

      private

      def compute
        debug_compute_config

        server_def = {
          provider:         :joyent,
          joyent_username:  config[:joyent_username],
          joyent_keyname:   config[:joyent_keyname],
          joyent_keyfile:   config[:joyent_keyfile],
          joyent_url:       config[:joyent_url],
        }

        Fog::Compute.new(server_def)
      end

      def create_server
        debug_server_config

        compute.servers.create(
          dataset:          config[:joyent_image_id],
          package:          config[:joyent_flavor_id],
          )
      end

      def debug_server_config
        debug("joyent: joyent_url #{config[:joyent_url]}")
        debug("joyent: image_id #{config[:joyent_image_id]}")
        debug("joyent: flavor_id #{config[:joyent_flavor_id]}")
      end

      def debug_compute_config
        debug("joyent_username #{config[:joyent_username]}")
        debug("joyent_keyname #{config[:joyent_keyname]}")
        debug("joyent_keyfile #{config[:joyent_keyfile]}")
      end
    end
  end
end
