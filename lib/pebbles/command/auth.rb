require "pebbles/command/base"

# authentication (login, logout)
#
class Pebbles::Command::Auth < Pebbles::Command::Base

  # auth
  #
  # Authenticate, display token and current user
  def index
    validate_arguments!

    Pebbles::Command::Help.new.send(:help_for_command, current_command)
  end

  # auth:login
  #
  # log in with your Pebblescape credentials
  #
  #Example:
  #
  # $ pebbles auth:login
  # Enter your Pebblescape credentials:
  # Email: email@example.com
  # Password (typing will be hidden):
  # Authentication successful.
  #
  def login
    validate_arguments!

    Pebbles::Auth.login
    display "Authentication successful."
  end

  alias_command "login", "auth:login"

  # auth:logout
  #
  # clear local authentication credentials
  #
  #Example:
  #
  # $ pebbles auth:logout
  # Local credentials cleared.
  #
  def logout
    validate_arguments!

    Pebbles::Auth.logout
    display "Local credentials cleared."
  end

  alias_command "logout", "auth:logout"

  # auth:token
  #
  # display your api token
  #
  #Example:
  #
  # $ pebbles auth:token
  # ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCD
  #
  def token
    validate_arguments!

    display Pebbles::Auth.api_key
  end

  # auth:whoami
  #
  # display your Pebblescape email address
  #
  #Example:
  #
  # $ pebbles auth:whoami
  # email@example.com
  #
  def whoami
    validate_arguments!

    display Pebbles::Auth.user
  end

end