# frozen_string_literal: true

require_relative "simple_ruby_lsp/version"

module SimpleRubyLsp
  class Error < StandardError; end

  class << self
    # @param argv [Array<String>]
    def start(argv)
      Signal.trap("INT", "EXIT")
      Signal.trap("TERM", "EXIT")
      File.open("tmp/lsp.log", "a") do |file|
        file << "\n\nArguments: #{argv}\n"

        file << "Messages\n"
        while (msg = $stdin.read)
          file << msg
        end
      end
    end
  end
end
