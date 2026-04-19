#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "socket"

request_path = ARGV.fetch(0)
request = JSON.parse(File.read(request_path))

listen_host = request.fetch("listen_host")
listen_port = request.fetch("listen_port")
target_host = request.fetch("target_host")
target_port = request.fetch("target_port")
ready_path = request.fetch("ready_path")
error_path = request.fetch("error_path")

begin
  server = TCPServer.new(listen_host, listen_port)
  File.write(ready_path, Process.pid.to_s)

  Signal.trap("TERM") do
    server.close rescue nil
    exit 0
  end

  loop do
    client = server.accept

    Thread.new(client) do |source|
      target = nil

      begin
        target = TCPSocket.new(target_host, target_port)

        upstream = Thread.new do
          IO.copy_stream(source, target)
        rescue StandardError
          nil
        ensure
          target.close_write rescue nil
        end

        downstream = Thread.new do
          IO.copy_stream(target, source)
        rescue StandardError
          nil
        ensure
          source.close_write rescue nil
        end

        upstream.join
        downstream.join
      ensure
        source.close rescue nil
        target&.close rescue nil
      end
    end
  end
rescue StandardError => error
  File.write(error_path, error.message)
  exit 1
end
