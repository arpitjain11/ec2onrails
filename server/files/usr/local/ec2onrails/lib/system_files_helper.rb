#    This file is part of EC2 on Rails.
#    http://rubyforge.org/projects/ec2onrails/
#
#    Copyright 2007 Paul Dowman, http://pauldowman.com/
#
#    EC2 on Rails is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    EC2 on Rails is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'fileutils'
require "#{File.dirname(__FILE__)}/system_files_manifest"
require "#{File.dirname(__FILE__)}/utils"

module Ec2onrails
  class SystemFilesHelper

    BACKUP_FILE_EXT = ".ec2onrails_backup"
    INSTALLED_MANIFEST_FILE = "/etc/ec2onrails/system_files/#{SystemFilesManifest::MANIFEST_FILE_NAME}"

    def install_system_files(from_dir)
      uninstall_system_files

      unless File.directory?(from_dir)
        puts "no system files to install, #{from_dir} doesn't exist or is not a directory."
        return
      end

      puts "installing system files from #{from_dir}..."
      src_manifest = File.join from_dir, SystemFilesManifest::MANIFEST_FILE_NAME

      @manifest = nil
      if File.exists? src_manifest
        @manifest = Ec2onrails::SystemFilesManifest.new(from_dir)
        FileUtils.cp src_manifest, INSTALLED_MANIFEST_FILE
      end

      FileUtils.cd from_dir do
        Dir.glob("**/.*").each do |f|
          unless File.directory?(f) || File.basename(f) == SystemFilesManifest::MANIFEST_FILE_NAME || [".", ".."].include?(f)
            dest = File.join("/", f)
            backup(dest)
            make_dirs(dest)
            install_file(f, dest, @manifest)
          end
        end
      end
    end

    def uninstall_system_files
      unless File.exist? INSTALLED_MANIFEST_FILE
        puts "not uninstalling system files, #{INSTALLED_MANIFEST_FILE} doesn't exist."
        return
      end

      puts "uninstalling system files..."
      @manifest = Ec2onrails::SystemFilesManifest.new(INSTALLED_MANIFEST_FILE)
      @manifest.filenames.each do |f|
        file = File.join("/", f)
        unless File.directory?(file)
          FileUtils.rm file
          restore_backup_of file
        end
      end
      FileUtils.rm INSTALLED_MANIFEST_FILE
    end

    def backup(f)
      if File.exist?(f)
        backup_file = f + "." + Time.now.strftime("%Y%m%d%H%M%S") + BACKUP_FILE_EXT
        puts "backing up file #{f} to #{backup_file} ..."
        FileUtils.mv f, backup_file
      end
    end

    def restore_backup_of(f)
      file_dir = File.dirname(f)
      file_timestamps = []

      FileUtils.cd file_dir do
        Dir.glob("**/#{f}*.ec2onrails_backup").each do |file_name|
          puts "File exist #{file_name}"
          file_timestamps << file_name.match("#{f}(\d+).ec2onrails_backup")[1]
        end
      end
      file_timestamps.sort!

      backup_file = f + "." + file_timestamps[0] + BACKUP_FILE_EXT
      if File.exist?(backup_file)
        puts "restoring backup of file #{f}..."
        FileUtils.mv backup_file, f
      end
    end

    def make_dirs(f)
      dir = File.dirname(f)
      unless dir == "/"
        puts "making dirs #{dir}..."
        FileUtils.mkdir_p File.dirname(f)
      end
    end

    def install_file(f, dest, manifest)
      puts "installing file #{f} into #{dest}..."
      FileUtils.cp f, dest
      if manifest
        Utils.run "chown #{manifest[f][:owner]} #{dest}" if manifest[f][:owner]
        Utils.run "chmod #{manifest[f][:mode]} #{dest}" if manifest[f][:mode]
      end
    end

  end
end
