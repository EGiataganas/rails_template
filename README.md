## Description

This is how I setup my Rails 6 projects.

## Requirements

This template currently works with:

* Rails 7.1.x
* Bundler 2.x
* PostgreSQL
* chromedriver

## Installation

*Optional.*

To make this the default Rails application template on your system, create a `~/.railsrc` file with these contents:

```
-d postgresql
-m https://raw.githubusercontent.com/EGiataganas/rails_template/main/template.rb
```

## Usage

This template assumes you will store your project in a remote git repository (e.g. Bitbucket or GitHub) and that you will deploy to a production environment. It will prompt you for this information in order to pre-configure your app, so be ready to provide:

1. The git URL of your (freshly created and empty) Bitbucket/GitHub repository
2. The hostname of your production server

To generate a Rails application using this template, pass the `-m` option to `rails new`, like this:

```
rails new blog \
  -d postgresql \
  -m https://raw.githubusercontent.com/EGiataganas/rails_template/main/template.rb
```

*Remember that options must go after the name of the application.* The only database supported by this template is `postgresql`.

If you’ve installed this template as your default (using `~/.railsrc` as described above), then all you have to do is run:

```
rails new blog
```

## What does it do?

The template will perform the following steps:

1. Generate your application files and directories
2. Ensure bundler is installed
3. Create the development and test databases
4. Commit everything to git
5. Push the project to the remote git repository you specified

## What is included?

#### Additional gems

* Utilities
    * [bootstrap][] - HTML, CSS, and JavaScript framework
    * [devise][] - flexible authentication solution for user creation
    * [rubocop][] – enforces Ruby code style
    * [simplecov][] - code coverage analysis tool
* Security
    * [brakeman][] and [bundler-audit][] – detect security vulnerabilities
* Testing
    * [capybara][] – shortcuts for common ActiveRecord tests
    * [factory_bot_rails][] - fixtures replacement
    * [pry-byebug][] - debugging
    * [rspec-rails][] - testing framework
    * [selenium-webdriver][] - writing automated tests

[bootstrap]:https://getbootstrap.com/
[brakeman]:https://github.com/presidentbeef/brakeman
[bundler-audit]:https://github.com/rubysec/bundler-audit
[capybara]: https://github.com/teamcapybara/capybara
[devise]: https://github.com/heartcombo/devise
[factory_bot_rails]: https://github.com/thoughtbot/factory_bot_rails
[pry-byebug]: https://github.com/deivid-rodriguez/pry-byebug
[rspec-rails]: https://github.com/rspec/rspec-rails
[rubocop]:https://github.com/bbatsov/rubocop
[selenium-webdriver]: https://github.com/SeleniumHQ/selenium/tree/trunk/rb
[simplecov]: https://github.com/simplecov-ruby/simplecov

[application templates]:http://guides.rubyonrails.org/generators.html#application-templates
[template.rb]: template.rb
