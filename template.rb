require 'fileutils'
require 'shellwords'

RAILS_REQUIREMENT = '~> 6.0.0'.freeze

def apply_template!
  assert_minimum_rails_version
  assert_valid_options
  add_template_repository_to_source_path

  template 'ruby-version.tt', '.ruby-version', force: true

  template 'Gemfile.tt', force: true

  template 'README.md.tt', force: true

  after_bundle do
    create_database
    initialize_rspec
    apply 'Rakefile.rb'
    apply 'lib/template.rb'
    add_bootstrap_through_webpack
    add_font_awesome_free if yes?('Do you want to install fontawesome-free?', :blue)
    run_rubocop_autocorrections
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

def gemfile_requirement(name)
  @original_gemfile ||= IO.read('Gemfile')
  req = @original_gemfile[/gem\s+['"]#{name}['"]\s*(,[><~= \t\d\.\w'"]*)?.*$/, 1]
  req && req.gsub("'", %(")).strip.sub(/^,\s*"/, ', "')
end

def git_repo_specified?
  git_repo_url != 'skip' && !git_repo_url.strip.empty?
end

def git_repo_url
  @git_repo_url ||=
    ask_with_default('What is the git remote URL for this project?', :blue, 'skip')
end

def ask_with_default(question, color, default)
  return default unless $stdin.tty?

  question = (question.split('?') << " [#{default}]?").join
  answer = ask(question, color)
  answer.to_s.strip.empty? ? default : answer
end

def preexisting_git_repo?
  @preexisting_git_repo ||= (File.exist?('.git') || :nope)
  @preexisting_git_repo == true
end

def any_local_git_commits?
  system('git log &> /dev/null')
end

def initialize_rspec
  rails_command 'generate rspec:install'

  apply 'spec/template.rb' if yes?('Do you want to apply RSpec suggested settings?', :blue)
end

def run_rubocop_autocorrections
  template 'rubocop.yml.tt', '.rubocop.yml'

  gsub_file 'config/environments/development.rb', "Rails.root.join('tmp', 'caching-dev.txt')", "Rails.root.join('tmp/caching-dev.txt')"

  run 'bundle exec rubocop --auto-correct-all --disable-uncorrectable'
  run 'bundle exec rubocop'
end

# Remove Application CSS
def add_bootstrap_through_webpack
  # Move image directory to javascript
  run 'mv app/assets/images app/javascript/images'

  # No longer needed this template uses webpack
  remove_file 'app/assets/'

  # Install bootstrap jquery popper.js node modules
  run 'yarn add bootstrap jquery popper.js'

  # Modify environment.js
  insert_into_file 'config/webpack/environment.js', before: 'module.exports = environment' do
    <<~EOF
      const webpack = require('webpack')

      environment.plugins.append(
        'Provide',
        new webpack.ProvidePlugin({
          $: 'jquery',
          jQuery: 'jquery',
          'window.jQuery': 'jquery',
          Popper: ['popper.js', 'default']
        })
      )
    EOF
  end

  # Import bootstrap
  insert_into_file 'app/javascript/packs/application.js', before: 'require("@rails/ujs").start()' do
    <<~EOF
      import "bootstrap"
      import "stylesheets/application"

    EOF
  end

  gsub_file 'app/javascript/packs/application.js', "//\n// const images = require.context('../images', true)", "\nconst images = require.context('../images', true)"

  gsub_file 'config/webpacker.yml', 'resolved_paths: []', 'resolved_paths: ["app/javascript/images"]'

  insert_into_file 'app/javascript/packs/application.js' do
    <<~EOF
      $(function () {
        $('[data-toggle="tooltip"]').tooltip()
        $('[data-toggle="popover"]').popover()
      })
    EOF
  end

  create_file 'app/javascript/stylesheets/application.scss'

  insert_into_file 'app/javascript/stylesheets/application.scss', '@import "~bootstrap/scss/bootstrap";'

  # Switch to stylesheet_pack_tag
  gsub_file 'app/views/layouts/application.html.erb', /stylesheet_link_tag/, 'stylesheet_pack_tag'
end

def add_font_awesome_free
  # Install fontawesome-free via yarn
  run 'yarn add @fortawesome/fontawesome-free'

  # Add reference to fontawesome-free to application.scss
  insert_into_file 'app/javascript/stylesheets/application.scss' do
    <<~EOF
      \n@import "~@fortawesome/fontawesome-free";
    EOF
  end

  # Import of fontawesome-free to application.js
  insert_into_file 'app/javascript/packs/application.js', "\nimport \"@fortawesome/fontawesome-free/js/all\"", after: 'import "stylesheets/application"'
end

def create_database
  return if Dir['db/migrate/**/*.rb'].any?

  rails_command 'db:create'
end

apply_template!
