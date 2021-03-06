require 'puppet/util/network_device/transport/ssh'

module Puppet
  module Cmc
    class Transport < Puppet::Util::NetworkDevice::Transport::Ssh
      attr_reader :hostname, :port, :username, :password
      attr_accessor :user, :password, :host, :port

      def initialize hostname, port, username, password
        # @transport = Puppet::Cmc::Util.get_transport
        @hostname = @host = hostname
        @port     = port
        @username = @user = username
        @password = password
        @default_prompt = /[$]\s?\z/n
        super()
        @timeout = Net::SSH::Connection::Session::DEFAULT_IO_SELECT_TIMEOUT
      end

      def connect
        i = 0
        begin
          super()
          #There probably shouldn't be any reason to do this, but trying to make the "least impactful changes" for now
          @client = @ssh
        rescue => e
          i += 1
          if i < 7
            Puppet.debug("Puppet::Util::NetworkDevice::Cmc::Transport failed to connect. retrying in 30 seconds...")
            sleep 30
            retry
          else
            raise e
          end
        end
      end

      def command(cmd, options = {})
        begin
          attempts ||= 1
          connect unless @ssh
          super
        rescue Net::SSH::Disconnect => e
          if attempts > 3
            raise e
          else
            attempts += 1
            Puppet.err("SSH Connection was closed by remote host. Attempting to reconnect in 5 seconds...")
            sleep 5
            connect
            retry
          end
        rescue Errno::ECONNRESET => e
          Puppet.err("SSH Connection reset by peer.  Retrying in 10 seconds...")
          sleep 10
          attempts += 1
          retry
        end
      end

      #We overwrite Puppet's method here because some switches require a \r as well to work
      def send(line)
        Puppet.debug("ssh: send #{line}") if @verbose
        @channel.send_data(line + "\r")
      end
    end
  end
end