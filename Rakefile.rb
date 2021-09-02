append_to_file 'Rakefile' do
  <<~RUBY

    task(:default).clear.enhance(%i[bundle_audit brakeman rubocop spec])
  RUBY
end
