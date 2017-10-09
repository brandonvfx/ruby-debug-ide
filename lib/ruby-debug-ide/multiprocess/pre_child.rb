module Debugger
  module MultiProcess
    class << self
      def pre_child(options = nil)
        require 'socket'
        require 'ostruct'

        host = ENV['DEBUGGER_HOST']
        sub_debugger_ports = if env['SUB_DEBUGGER_PORT_RANGE']
                              ENV['SUB_DEBUGGER_PORT_RANGE'].split(/-/)
                            else
                              nil
                            end
        
        options ||= OpenStruct.new(
            'frame_bind'  => false,
            'host'        => host,
            'load_mode'   => false,
            'port'        => find_free_port(host, sub_debugger_ports),
            'stop'        => false,
            'tracing'     => false,
            'int_handler' => true,
            'cli_debug'   => (ENV['DEBUGGER_CLI_DEBUG'] == 'true'),
            'notify_dispatcher' => true,
            'evaluation_timeout' => 10,
            'sub_debugger_port_range' => sub_debugger_ports 
        )

        if(options.ignore_port)
          options.port = find_free_port(options.host, sub_debugger_ports)
          options.notify_dispatcher = true
        end
      
        start_debugger(options)
      end

      def start_debugger(options)
        if Debugger.started?
          # we're in forked child, only need to restart control thread
          Debugger.breakpoints.clear
          Debugger.control_thread = nil
          Debugger.start_control(options.host, options.port, options.notify_dispatcher)
        end

        if options.int_handler
          # install interruption handler
          trap('INT') { Debugger.interrupt_last }
        end

        # set options
        Debugger.keep_frame_binding = options.frame_bind
        Debugger.tracing = options.tracing
        Debugger.evaluation_timeout = options.evaluation_timeout
        Debugger.cli_debug = options.cli_debug
        Debugger.prepare_debugger(options)
      end


      def find_free_port(host, sub_debugger_ports=nil)
        if sub_debugger_ports.nil?
          server = TCPServer.open(host, 0)
          port   = server.addr[1]
          server.close
          port
        else
          ports = Range.new(sub_debugger_ports[0], sub_debugger_ports[1]).to_a
          begin
            raise "No available ports in range #{child_process_ports[0]}-#{child_process_ports[1]}" if ports.empty?
            port = ports.sample
            server = TCPServer.open(host, port)
            server.close
            port
          rescue Errno::EADDRINUSE
            ports.delete(port)
            retry
          end
        end
      end
    end
  end
end