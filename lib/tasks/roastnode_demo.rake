namespace :roastnode do
  namespace :demo do
    desc "Load optional Roastnode demo household data"
    task load: :environment do
      if Rails.env.production? && ENV["ROASTNODE_ALLOW_DEMO_DATA"] != "1"
        abort "Refusing to create demo credentials in production. Set ROASTNODE_ALLOW_DEMO_DATA=1 to override."
      end

      result = DemoDataSeeder.new.call

      puts "Demo data #{result.fetch(:status)}."
      puts "Email: #{result.fetch(:email)}"
      puts "Password: #{result.fetch(:password)}"
      puts "Workspace: #{result.fetch(:workspace)}"
    end
  end
end
