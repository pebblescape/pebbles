require "pebbles/command/base"

# manage apps (create, destroy)
#
class Pebbles::Command::Apps < Pebbles::Command::Base

  # apps
  #
  # list your apps
  #
  #Example:
  #
  # $ pebbles apps
  # === My Apps
  # example
  # example2
  #
  def index
    validate_arguments!

    apps = api.get_apps.body

    unless apps.empty?
      styled_header("My Apps")
      styled_array(apps.map { |app| app_name(app) })
    else
      display("You have no apps.")
    end
  end

  alias_command "list", "apps"

  # apps:info
  #
  # show detailed app information
  #
  # -s, --shell  # output more shell friendly key/value pairs
  #
  #Examples:
  #
  # $ pebbles apps:info
  # === example
  # Git URL:   https://git.pebblescape.com/example.git
  # Repo Size: 5M
  # ...
  #
  # $ pebbles apps:info --shell
  # git_url=https://git.pebblescape.com/example.git
  # repo_size=5000000
  # ...
  #
  def info
    validate_arguments!
    app_data = api.get_app(app).body

    unless options[:shell]
      styled_header(app_data["name"])
    end
    
    if options[:shell]
      app_data['git_url'] = git_url(app_data['name'])
      if app_data['domain_name']
        app_data['domain_name'] = app_data['domain_name']['domain']
      end
      app_data['owner'].delete('id')
      flatten_hash(app_data, 'owner')
      app_data.keys.sort_by { |a| a.to_s }.each do |key|
        hputs("#{key}=#{app_data[key]}")
      end
    else
      data = {}
      
      if app_data["create_status"] && app_data["create_status"] != "complete"
        data["Create Status"] = app_data["create_status"]
      end

      data["Git URL"] = git_url(app_data['name'])

      
      if app_data["owner"]
        data["Owner Email"] = app_data["owner"]["email"]
        data["Owner"] = app_data["owner"]["name"]
      end
      data["Repo Size"] = format_bytes(app_data["repo_size"]) if app_data["repo_size"]
      data["Build Size"] = format_bytes(app_data["build_size"]) if app_data["build_size"]
      data["Web URL"] = app_data["web_url"]

      styled_hash(data)
    end
  end

  alias_command "info", "apps:info"

  # apps:create [NAME]
  #
  # create a new app
  #
  #     --addons ADDONS        # a comma-delimited list of addons to install
  # -b, --buildpack BUILDPACK  # a buildpack url to use for this app
  # -n, --no-remote            # don't create a git remote
  # -r, --remote REMOTE        # the git remote to create, default "pebbles"
  #     --ssh-git              # Use SSH git protocol
  #     --http-git             # HIDDEN: Use HTTP git protocol
  #
  #Examples:
  #
  # $ pebbles apps:create
  # Creating floating-dragon-42... done, stack is cedar
  # http://floating-dragon-42.pebblesinspace.com/ | https://git.pebblesinspace.com/floating-dragon-42.git
  #
  # # specify a name
  # $ pebbles apps:create example
  # Creating example... done, stack is cedar
  # http://example.pebblesinspace.com/ | https://git.pebblesinspace.com/example.git
  #
  # # create a staging app
  # $ pebbles apps:create example-staging --remote staging
  #
  def create
    name    = shift_argument || options[:app] || ENV['PEBBLES_APP']
    validate_arguments!

    params = {
      "name" => name,
    }

    info = api.post_app(params).body

    begin
      action("Creating #{info['name']}") do
        if info['create_status'] == 'creating'
          Timeout::timeout(options[:timeout].to_i) do
            loop do
              break if api.get_app(info['name']).body['create_status'] == 'complete'
              sleep 1
            end
          end
        end
      end

      # (options[:addons] || "").split(",").each do |addon|
      #   addon.strip!
      #   action("Adding #{addon} to #{info["name"]}") do
      #     api.post_addon(info["name"], addon)
      #   end
      # end

      if buildpack = options[:buildpack]
        api.put_config_vars(info["name"], "BUILDPACK_URL" => buildpack)
        display("BUILDPACK_URL=#{buildpack}")
      end

      hputs([ info["web_url"], git_url(info['name']) ].join(" | "))
    rescue Timeout::Error
      hputs("Timed Out! Run `pebbles status` to check for known platform issues.")
    end

    unless options[:no_remote].is_a? FalseClass
      create_git_remote(options[:remote] || "pebbles", git_url(info['name']))
    end
  end

  alias_command "create", "apps:create"

  # apps:destroy --app APP
  #
  # permanently destroy an app
  #
  #Example:
  #
  # $ pebbles apps:destroy -a example --confirm example
  # Destroying example (including all add-ons)... done
  #
  def destroy
    @app = shift_argument || options[:app] || options[:confirm]
    validate_arguments!

    unless @app
      error("Usage: pebbles apps:destroy --app APP\nMust specify APP to destroy.")
    end

    api.get_app(@app) # fail fast if no access or doesn't exist

    message = "WARNING: Potentially Destructive Action\nThis command will destroy #{@app} (including all add-ons)."
    if confirm_command(@app, message)
      action("Destroying #{@app} (including all add-ons)") do
        api.delete_app(@app)
        if remotes = git_remotes(Dir.pwd)
          remotes.each do |remote_name, remote_app|
            next if @app != remote_app
            git "remote rm #{remote_name}"
          end
        end
      end
    end
  end

  alias_command "destroy", "apps:destroy"
  alias_command "apps:delete", "apps:destroy"
  
  # apps:open --app APP
  #
  # open the app in a web browser
  #
  #Example:
  #
  # $ heroku apps:open
  # Opening example... done
  #
  def open
    path = shift_argument
    validate_arguments!

    app_data = api.get_app(app).body

    url = [app_data['web_url'], path].join
    launchy("Opening #{app}", url)
  end

  private

  def app_name(app)
    app["name"]
  end
end