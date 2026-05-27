namespace :roastnode do
  namespace :backup do
    desc "Validate a Roastnode instance backup archive"
    task :validate, [ :path ] => :environment do |_task, args|
      abort "Usage: bin/rails roastnode:backup:validate[/path/to/backup.zip]" if args[:path].blank?

      result = InstanceBackupArchiveValidator.new(args.fetch(:path)).call
      if result.valid?
        puts "Backup archive is valid."
      else
        abort result.errors.to_sentence
      end
    end

    desc "Restore a Roastnode instance backup archive into an empty server"
    task :restore, [ :path ] => :environment do |_task, args|
      abort "Usage: bin/rails roastnode:backup:restore[/path/to/backup.zip]" if args[:path].blank?

      summary = InstanceBackupRestorer.new(args.fetch(:path)).call
      puts "Restored #{summary.fetch(:users)} users, #{summary.fetch(:workspaces)} workspaces, #{summary.fetch(:brews)} brews, and #{summary.fetch(:media_files)} media files."
    rescue InstanceBackupRestorer::RestoreError => error
      abort error.message
    end
  end
end
