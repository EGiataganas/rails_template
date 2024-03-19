require 'fileutils'
require 'shellwords'

RAILS_REQUIREMENT = '~> 7.1.3'.freeze

def apply_template!
  assert_minimum_rails_version
  assert_valid_options
  add_template_repository_to_source_path

  template 'ruby-version.tt', '.ruby-version', force: true

  template 'Gemfile.tt', force: true

  template 'README.md.tt', force: true

  after_bundle do
    pin_and_config_js_libs
    bootstrap_template
    create_database
    initialize_rspec
    initialize_simple_form
    add_localization
    add_users
    apply 'Rakefile.rb'
    apply 'lib/template.rb'
    copy_templates
    run_rubocop_autocorrections
    rails_command 'db:migrate'
    run 'bundle exec rake'

    git :init unless preexisting_git_repo?
    unless any_local_git_commits?
      git add: '-A .'
      git commit: %( -m "Project setup" )
      if git_repo_specified?
        git remote: "add origin #{git_repo_url.shellescape}"
        git push: '-u origin --all'
      end
    end

    say "Your app #{app_name} has been successfully created!", :green
    say
    say 'Switch to your app by running:'
    say "$ cd #{app_name}", :yellow
    say
    say 'Then run:'
    say '$ rails server', :green
  end
end

def assert_minimum_rails_version
  requirement = Gem::Requirement.new(RAILS_REQUIREMENT)
  rails_version = Gem::Version.new(Rails::VERSION::STRING)
  return if requirement.satisfied_by?(rails_version)

  prompt = "This template requires Rails #{RAILS_REQUIREMENT}. "\
           "You are using #{rails_version}. Continue anyway?"
  exit 1 if no?(prompt)
end

# Bail out if user has passed in contradictory generator options.
def assert_valid_options
  valid_options = {
    skip_gemfile: false,
    skip_bundle: false,
    skip_git: false,
    edge: false
  }

  valid_options.each do |key, expected|
    next unless options.key?(key)

    actual = options[key]
    raise Rails::Generators::Error, "Unsupported option: #{key}=#{actual}" unless actual == expected
  end
end

# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
def add_template_repository_to_source_path
  if __FILE__ =~ %r{\Ahttps?://}
    require 'tmpdir'
    source_paths.unshift(tempdir = Dir.mktmpdir('rails_template-'))
    at_exit { FileUtils.remove_entry(tempdir) }
    git clone: [
      '--quiet',
      'https://github.com/EGiataganas/rails_template.git',
      tempdir
    ].map(&:shellescape).join(' ')

    if (branch = __FILE__[%r{rails_template/(.+)/template.rb}, 1])
      Dir.chdir(tempdir) { git checkout: branch }
    end
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

def gemfile_entry(name, version=nil, require: true, force: false)
  @original_gemfile ||= IO.read("Gemfile")
  entry = @original_gemfile[/^\s*gem #{Regexp.quote(name.inspect)}.*$/]
  return if entry.nil? && !force

  require = (entry && entry[/\brequire:\s*([\S]+)/, 1]) || require
  version = (entry && entry[/, "([^"]+)"/, 1]) || version
  args = [name.inspect, version&.inspect, ("require: false" if require != true)].compact
  "gem #{args.join(", ")}\n"
end

def create_database
  return if Dir['db/migrate/**/*.rb'].any?

  rails_command 'db:create'
end

def initialize_rspec
  rails_command 'generate rspec:install'

  apply 'spec/template.rb' if yes?('Do you want to apply RSpec suggested settings?', :blue)
end

def initialize_simple_form
  rails_command 'generate simple_form:install --bootstrap'
end

def add_users
  # Install Devise
  rails_command 'generate devise:install'

  copy_file 'config/initializers/devise.rb', force: true

  # Configure Devise
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: 'development'

  route "root 'home#show'"

  # We don't use rails_command here to avoid accidentally having RAILS_ENV=development as an attribute
  run 'rails generate devise User'

  inject_into_file 'app/controllers/application_controller.rb', after: 'class ApplicationController < ActionController::Base' do
    "\n before_action :authenticate_user! \n"
  end

  copy_file 'bootstrap/views/layouts/devise.html.erb', 'app/views/layouts/devise.html.erb', force: true
  copy_file 'bootstrap/assets/devise.scss', 'app/assets/stylesheets/devise.scss', force: true

  directory 'bootstrap/views/devise', 'app/views/devise', force: true

  inject_into_file 'app/assets/stylesheets/application.bootstrap.scss', after: "@import 'bootstrap-icons/font/bootstrap-icons';" do
    "\n\n@import 'devise'"
  end

  copy_file 'db/seeds.rb', force: true

  copy_file 'config/locales/devise.el.yml', force: true
  copy_file 'config/locales/devise.en.yml', force: true

  rails_command 'db:seed'
end

def ask_with_default(question, color, default)
  return default unless $stdin.tty?

  question = (question.split('?') << " [#{default}]?").join
  answer = ask(question, color)
  answer.to_s.strip.empty? ? default : answer
end

def git_repo_specified?
  git_repo_url != 'skip' && !git_repo_url.strip.empty?
end

def git_repo_url
  @git_repo_url ||=
    ask_with_default('What is the git remote URL for this project?', :blue, 'skip')
end

def preexisting_git_repo?
  @preexisting_git_repo ||= (File.exist?('.git') || :nope)
  @preexisting_git_repo == true
end

def any_local_git_commits?
  system('git log &> /dev/null')
end

def copy_templates
  directory "app", force: true
end

def pin_and_config_js_libs
  old_content_for_application = <<~JS
    import * as bootstrap from "bootstrap"
  JS

  new_content_for_application = <<~JS
    import './src/jquery'
    import './src/popper'
    import './src/bootstrap'
    import './src/tooltip'
  JS

  gsub_file 'app/javascript/application.js', old_content_for_application, new_content_for_application

  run 'bin/importmap pin jquery'

  inject_into_file 'config/importmap.rb', before: "\n" do
    "\n pin '@popperjs/core', to: 'https://unpkg.com/@popperjs/core@2.11.8/dist/esm/index.js'"
  end
end

def bootstrap_template
  copy_file "bootstrap/views/layouts/application.html.erb", "app/views/layouts/application.html.erb", force: true
end

def add_localization
  additional_settings = "
    config.i18n.available_locales = %i[el en]
    config.i18n.default_locale = :el
  "

  inject_into_file 'config/application.rb', after: 'config.generators.system_tests = nil' do
    additional_settings
  end

  inject_into_file 'app/controllers/application_controller.rb', after: 'class ApplicationController < ActionController::Base' do
    "\n include Localisation \n"
  end

  inject_into_file 'config/routes.rb', after: 'Rails.application.routes.draw do' do
    "\n scope '(:locale)', locale: Regexp.union(I18n.available_locales.map(&:to_s)) do \n"
  end

  inject_into_file 'config/routes.rb', after: "root 'home#show'" do
    "\n end"
  end

  copy_file 'config/locales/el.yml', force: true
end

def run_rubocop_autocorrections
  template 'rubocop.yml.tt', '.rubocop.yml'

  gsub_file 'config/environments/development.rb', "Rails.root.join('tmp', 'caching-dev.txt')", "Rails.root.join('tmp/caching-dev.txt')"

  run 'bundle exec rubocop --auto-correct-all --disable-uncorrectable'
  run 'bundle exec rubocop'
end

apply_template!
