require 'pebbles'
require 'pebbles/command'
require 'pebbles/git'
require 'pebbles/helpers'
require 'excon'

class Pebbles::CLI
  extend Pebbles::Helpers

  def self.start(*args)
    $stdin.sync = true if $stdin.isatty
    $stdout.sync = true if $stdout.isatty
    Pebbles::Git.check_git_version
    command = args.shift.strip rescue "help"
    Pebbles::Command.load
    Pebbles::Command.run(command, args)
  rescue Errno::EPIPE => e
    error(e.message)
  rescue Interrupt => e
    `stty icanon echo`
    if ENV["PEBBLES_DEBUG"]
      styled_error(e)
    else
      error("Command cancelled.", false)
    end
  rescue => error
    if ENV["PEBBLES_DEBUG"]
      raise
    else
      styled_error(error)
    end
    exit(1)
  end

end