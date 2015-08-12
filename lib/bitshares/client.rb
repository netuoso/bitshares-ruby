module Bitshares

  class Client

    def self.init
      @user = ENV['BITSHARES_ACCOUNT']
      @password = ENV['BITSHARES_PASSWORD']
      @@rpc_instance = Bitshares::Client::Rpc.new(@user, @password)
      return self
    end

    def self.rpc
      @@rpc_instance
    end

    def self.synced?
      blockchain_get_block_count >= self.get_info['blockchain_head_block_num']
    end

    def self.method_missing(m, *args)
      @@rpc_instance.request(m, args)
    end

    class Rpc

      class Err < RuntimeError; end

      def initialize(user, password)
        bitshares_running?
        @uri = URI("http://localhost:#{rpc_http_port}/rpc")
        @req = Net::HTTP::Post.new(@uri)
        @req.content_type = 'application/json'
        @req.basic_auth user, password
      end

      def request(m, args = [])
        resp = nil
        Net::HTTP.start(@uri.hostname, @uri.port) do |http|
          @req.body = { method: m, params: args, jsonrpc: '2.0', id: 0 }.to_json
          resp = http.request(@req)
        end
        raise Err, 'Bad credentials' if resp.class == Net::HTTPUnauthorized
        result = JSON.parse(resp.body)
        e = result['error']
        raise Err, JSON.pretty_generate(e), "#{m} #{args.join(' ') if args}" if e
        return result['result']
      end

      private

      def bitshares_running?
        raise Err, 'Server not running!' unless rpc_ports.count == 2
      end

      def rpc_http_port
        rpc_ports.each do |port| # only http RPC port raises a non-empty response
          return port unless `curl -s -I -L http://localhost:#{port}`.empty?
        end
      end

      def rpc_ports # returns bitshares HTTP JSON RPC and JSON RPC server ports
        `lsof -iTCP@localhost | grep bitshares`.scan(/:(\d+) \(LISTEN\)/).flatten
      end

    end

  end

end
