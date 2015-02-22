namespace :import do
  require 'fileutils'

  desc "Import Postcode & area data"
  task db: :environment do
    # Move to tmp dir
    FileUtils.rm_rf Rails.root.join('tmp', 'import')
    FileUtils.mkdir_p Rails.root.join('tmp', 'import')
    Dir.chdir Rails.root.join('tmp', 'import')

    # Run import script inside tmp dir
    IO.popen("#{Rails.root.join('lib', 'import.sh')} #{Rails.env}").each do |line|
        puts line.chomp
    end
    # Remove mess
    FileUtils.rm_rf Rails.root.join('tmp', 'import')
  end

end
