# frozen_string_literal: true

require "json"
require "uri"
require_relative "simple_ruby_lsp/version"

module SimpleRubyLsp
  class Error < StandardError; end

  class << self
    # @param argv [Array<String>]
    def start(argv)
      # @param file [File]
      file = File.open("/home/dushyant/lsp.log", "a")
      file << "\n\nArguments: #{argv}\n"

      file << "Messages\n"
      file.flush

      input = IO.open(0)
      output = IO.open(1)

      Signal.trap("INT") do
        puts "INT"
        input.close
        output.close
        file.close
        exit(0)
      end

      Signal.trap("TERM") do
        puts "TERM"
        input.close
        output.close
        file.close
        exit(0)
      end

      loop do
        process_message(input, output, file)
      end
    end

    # @param input [IO]
    # @param output [IO]
    # @param file [File]
    def process_message(input, output, file)
      content_length_message = input.gets("\r\n")
      content_length = /\d+/.match(content_length_message)[0].to_i
      file << "Content Length is #{content_length}\n"

      next_line = input.gets("\r\n")
      # Discard header if exists, else we've already discarded the blank line separator
      input.gets("\r\n") if next_line.length != 2

      content = input.read(content_length)
      message = parse_message(content)

      file << message
      file << "\n"
      file.flush

      response = case message["method"]
      when "initialize"
        initialize_response(message)
      when "textDocument/hover"
        hover_response(message)
      end

      return unless response

      file << response
      file << "\n"
      file.flush

      output.write(response)
      output.flush
    end

    # @param content [String]
    # @return [Hash]
    def parse_message(content)
      JSON.parse(content)
    end

    # @param message [Hash]
    # @return [String]
    def initialize_response(message)
      result = {
        capabilities: {
          hoverProvider: true,
        },
        serverInfo: {
          name: "simple_ruby_lsp",
          version: VERSION,
        },
      }

      response = {
        id: message["id"],
        jsonrpc: message["jsonrpc"],
        result: result,
      }.to_json

      "Content-Length: #{response.bytesize}\r\n\r\n#{response}"
    end

    # @param message [Hash]
    # @return [String]
    def hover_response(message)
      result = nil
      filename = message["params"]["textDocument"]["uri"]
      position = message["params"]["position"]
      if filename.end_with?("/Gemfile")
        # @param f [File]
        File.open(URI.parse(filename).path, "r") do |f|
          line = f.readlines[position["line"]]

          match = /^\s*gem\s*\(?\s*["'](.+?)["']/.match(line)
          match_end = match.end(1) if match
          match_start = match.end(1) - match.match_length(1) if match
          if match && position["character"] < match_end && position["character"] >= match_start
            gem = match[1]
            contents = %x(gem info #{gem})

            range = {
              start: {
                line: position["line"],
                character: match_start,
              },
              end: {
                line: position["line"],
                character: match_end,
              },
            }

            result = {
              contents: contents,
              range: range,
            }
          end
        end
      end

      response = {
        id: message["id"],
        jsonrpc: message["jsonrpc"],
        result: result,
      }.to_json

      "Content-Length: #{response.bytesize}\r\n\r\n#{response}"
    end
  end
end
