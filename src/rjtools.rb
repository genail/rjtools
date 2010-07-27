#!/usr/bin/env ruby

require 'tempfile'
require 'tmpdir'
require 'rubygems'
require 'zip/zip'
require 'ftools'

module RJ

    class Args
        def self.contains?(key)
            return ARGV.index(key_to_opt(key)) != nil
        end
    
        def self.value_of(key)
            index = ARGV.index(key_to_opt(key))
            
            if index.nil?
                return nil
            end
            
            return ARGV[index + 1]
        end
        
        private
        
        def self.key_to_opt(key)
            prefix = nil
        
            if key.size == 1
                prefix = '-'
            elsif key.size > 1
                prefix = '--'
            end
            
            return prefix + key
        end
    end

    class Temp
        def self.directory
            Dir.mktmpdir()
        end
        
        def self.file(dir=nil)
            Tempfile.new('ruby', Dir::tmpdir)
        end
        
        def self.path
            f = Temp.file()
            path = f.path
            f.unlink
            
            return path
        end
    end
    
    class FileSystem
        def self.tree(dirpath)
            result = []

            Dir.open(dirpath) do |dir|
                dir.each do |entry|
                    if entry == "." or entry == ".."
                        next
                    end
                    
                    fullpath = dirpath + "/" + entry
                    result.push fullpath
                    
                    if File.directory? fullpath
                        result = result + tree(fullpath)
                    end
                end
            end
            
            return result
        end
    end

    class Zip
        def self.access(zipFile, zipEntry)
            path = Temp.path()
            Zip.unpack(zipFile, zipEntry, path)
            
            yield path
            
            Zip.insert(zipFile, path, zipEntry)
            File.unlink path
        end
        
        def self.create(zipFile, zipEntry)
            path = Temp.file().path
            yield path
            Zip.insert(zipFile, path, zipEntry)
            File.unlink path
        end
        
        def self.pack(source, zipFile)
            ::Zip::ZipFile.open(zipFile, ::Zip::ZipFile::CREATE) do |zip|
                tr = FileSystem.tree(source)
                tr.each do |el|
                    dest = el[(source.size + 1)..-1]
                    zip.add(dest, el)
                end
            end
        end
        
        def self.unpack(zipFile, zipEntry, destination)
            ::Zip::ZipFile.open(zipFile) do |file|
                entry = file.get_entry(zipEntry)
                entry.extract(destination)
            end
        end
        
        def self.unpackAll(zipFile, destination)
            ::Zip::ZipFile.open(zipFile) do |zip_file|
                zip_file.each do |f|
                    f_path=File.join(destination, f.name)
                    FileUtils.mkdir_p(File.dirname(f_path))
                    zip_file.extract(f, f_path) unless File.exist?(f_path)
                end
            end
        end
        
        def self.insert(zipFile, source, zipEntry)
            ::Zip::ZipFile.open(zipFile) do |file|
                if file.find_entry(zipEntry).nil?
                    file.add(zipEntry, source)
                else
                    file.replace(zipEntry, source)
                end
            end
        end
    end
    
    class Template
        def self.compile(source, destination=nil)
        
            move_back = false
            if destination.nil?
                destination = Tempfile.new("ruby").path
                move_back = true
            end
        
            replace_map = yield
        
            File.open(source, "r") do |input|
                File.open(destination, "w") do |output|
                    input.each_line do |in_line|
                        replace_map.each do |key, value|
                            in_line.gsub!(key, value)
                        end
                        
                        output << in_line
                    end
                end
            end
            
            if move_back
                File.move(destination, source)
            end
        end
    end
end

#RJ::Zip.access('/tmp/c/plik.zip', 'b') do |path|
#    File.open(path, "w") do |f|
#        f << "hello world"
#    end
#    
#    RJ::Template.compile(path) {{
#        "hello" => "goodbye"
#    }}
#end
#
#RJ::Zip.unpackAll('/tmp/c/plik.zip', '/tmp/c/a')
#RJ::Zip.pack('/tmp/c/a', '/tmp/c/plik2.zip')

#puts "found -a" if RJ::Args.contains? 'a'
#puts "found --long" if RJ::Args.contains? 'long'
#puts "long value: #{RJ::Args.value_of('long')}"
