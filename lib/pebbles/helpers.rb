module Pebbles
  module Helpers
    extend self
    
    def home_directory
      return Dir.home if defined? Dir.home # Ruby 1.9+
      running_on_windows? ? ENV['USERPROFILE'].gsub("\\","/") : ENV['HOME']
    end

    def running_on_windows?
      RUBY_PLATFORM =~ /mswin32|mingw32/
    end

    def running_on_a_mac?
      RUBY_PLATFORM =~ /-darwin\d/
    end
    
    def launchy(message, url)
      action(message) do
        require("launchy")
        launchy = Launchy.open(url)
        if launchy.respond_to?(:join)
          launchy.join
        end
      end
    end
    
    def output_with_bang(message="", new_line=true)
      return if message.to_s.strip == ""
      display(format_with_bang(message), new_line)
    end
    
    def format_with_bang(message)
      return '' if message.to_s.strip == ""
      " !    " + message.split("\n").join("\n !    ")
    end
    
    def display(msg="", new_line=true)
      if new_line
        puts(msg)
      else
        print(msg)
      end
      $stdout.flush
    end
    
    def debug(*args)
      $stderr.puts(*args) if debugging?
    end
    
    def debugging?
      ENV['PEBBLES_DEBUG']
    end
    
    def ask
      $stdin.gets.to_s.strip
    end
    
    def error(message, report=false)
      if Pebbles::Helpers.error_with_failure
        display("failed")
        Pebbles::Helpers.error_with_failure = false
      end
      $stderr.puts(format_with_bang(message))
      exit(1)
    end
    
    def self.error_with_failure
      @@error_with_failure ||= false
    end

    def self.error_with_failure=(new_error_with_failure)
      @@error_with_failure = new_error_with_failure
    end
    
    def hputs(string='')
      Kernel.puts(string)
    end
    
    def longest(items)
      items.map { |i| i.to_s.length }.sort.last
    end
    
    def has_git?
      %x{ git --version }
      $?.success?
    end

    def git(args)
      return "" unless has_git?
      flattened_args = [args].flatten.compact.join(" ")
      %x{ git #{flattened_args} 2>&1 }.strip
    end
    
    def has_git_remote?(remote)
      git('remote').split("\n").include?(remote) && $?.success?
    end

    def create_git_remote(remote, url)
      return if has_git_remote? remote
      git "remote add #{remote} #{url}"
      display "Git remote #{remote} added" if $?.success?
    end

    def update_git_remote(remote, url)
      return unless has_git_remote? remote
      git "remote set-url #{remote} #{url}"
      display "Git remote #{remote} updated" if $?.success?
    end
    
    @@kb = 1024
    @@mb = 1024 * @@kb
    @@gb = 1024 * @@mb
    def format_bytes(amount)
      amount = amount.to_i
      return '(empty)' if amount == 0
      return amount if amount < @@kb
      return "#{(amount / @@kb).round}k" if amount < @@mb
      return "#{(amount / @@mb).round}M" if amount < @@gb
      return "#{(amount / @@gb).round}G"
    end
    
    def json_decode(json)
      MultiJson.load(json)
    rescue MultiJson::ParseError
      nil
    end
    
    def with_tty(&block)
      return unless $stdin.isatty
      begin
        yield
      rescue
        # fails on windows
      end
    end
    
    def action(message, options={})
      message = "#{message} in organization #{org}" if options[:org]
      display("#{message}... ", false)
      Pebbles::Helpers.error_with_failure = true
      ret = yield
      Pebbles::Helpers.error_with_failure = false
      display((options[:success] || "done"), false)
      if @status
        display(", #{@status}", false)
        @status = nil
      end
      display
      ret
    end
    
    def confirm_command(app_to_confirm = app, message=nil)
      if confirmed_app = Pebbles::Command.current_options[:confirm]
        unless confirmed_app == app_to_confirm
          raise(Pebbles::Command::CommandFailed, "Confirmed app #{confirmed_app} did not match the selected app #{app_to_confirm}.")
        end
        return true
      else
        display
        message ||= "WARNING: Destructive Action\nThis command will affect the app: #{app_to_confirm}"
        message << "\nTo proceed, type \"#{app_to_confirm}\" or re-run this command with --confirm #{app_to_confirm}"
        output_with_bang(message)
        display
        display "> ", false
        if ask.downcase != app_to_confirm
          error("Confirmation did not match #{app_to_confirm}. Aborted.")
        else
          true
        end
      end
    end
    
    def format_error(error, message='Pebblescape client internal error.')
      formatted_error = []
      formatted_error << " !    #{message}"
      formatted_error << ''
      formatted_error << "    Error:       #{error.message} (#{error.class})"
      command = ARGV.map do |arg|
        if arg.include?(' ')
          arg = %{"#{arg}"}
        else
          arg
        end
      end.join(' ')
      formatted_error << "    Command:     pebbles #{command}"
      require 'pebbles/auth'
      unless Pebbles::Auth.host == Pebbles::Auth.default_host
        formatted_error << "    Host:        #{Pebbles::Auth.host}"
      end
      if http_proxy = ENV['http_proxy'] || ENV['HTTP_PROXY']
        formatted_error << "    HTTP Proxy:  #{http_proxy}"
      end
      if https_proxy = ENV['https_proxy'] || ENV['HTTPS_PROXY']
        formatted_error << "    HTTPS Proxy: #{https_proxy}"
      end
      formatted_error << "    Version:     #{Pebbles.user_agent}"
      formatted_error << "\n"
      formatted_error.join("\n")
    end
    
    def styled_header(header)
      display("=== #{header}")
    end
    
    # produces a printf formatter line for an array of items
    # if an individual line item is an array, it will create columns
    # that are lined-up
    #
    # line_formatter(["foo", "barbaz"])                 # => "%-6s"
    # line_formatter(["foo", "barbaz"], ["bar", "qux"]) # => "%-3s   %-6s"
    #
    def line_formatter(array)
      if array.any? {|item| item.is_a?(Array)}
        cols = []
        array.each do |item|
          if item.is_a?(Array)
            item.each_with_index { |val,idx| cols[idx] = [cols[idx]||0, (val || '').length].max }
          end
        end
        cols.map { |col| "%-#{col}s" }.join("  ")
      else
        "%s"
      end
    end

    def styled_array(array, options={})
      fmt = line_formatter(array)
      array = array.sort unless options[:sort] == false
      array.each do |element|
        display((fmt % element).rstrip)
      end
      display
    end
    
    def styled_hash(hash, keys=nil)
      max_key_length = hash.keys.map {|key| key.to_s.length}.max + 2
      keys ||= hash.keys.sort {|x,y| x.to_s <=> y.to_s}
      keys.each do |key|
        case value = hash[key]
        when Array
          if value.empty?
            next
          else
            elements = value.sort {|x,y| x.to_s <=> y.to_s}
            display("#{key}: ".ljust(max_key_length), false)
            display(elements[0])
            elements[1..-1].each do |element|
              display("#{' ' * max_key_length}#{element}")
            end
            if elements.length > 1
              display
            end
          end
        when nil
          next
        else
          display("#{key}: ".ljust(max_key_length), false)
          display(value)
        end
      end
    end
    
    def flatten_hash(hash, key)
      hash[key].each do |k, v|
        hash["#{key}_#{k}"] = v
      end
      
      hash.delete(key)
    end
    
    def styled_error(error, message='Pebblescape client internal error.')
      if Pebbles::Helpers.error_with_failure
        display("failed")
        Pebbles::Helpers.error_with_failure = false
      end
      $stderr.puts(format_error(error, message))
    end
    
    def has_http_git_entry_in_netrc
      Auth.netrc && Auth.netrc[Auth.http_git_host]
    end
  end
end