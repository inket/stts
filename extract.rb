require 'net/https'
require 'nokogiri'
require 'xcodeproj'
require 'json'
require 'synx'

@project_file = "stts.xcodeproj"

def source_for(url)
    uri = URI.parse(url)
    path = uri.path == "" ? "/" : uri.path
    result = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |http| http.get(path) }
    result.code.to_i == 200 ? result.body : nil
end

def extract_instatus(source)
    document = Nokogiri::HTML(source)

    document.css("#__NEXT_DATA__").each do |data|
        site = JSON.parse(data.inner_html)["props"]["pageProps"]["site"]

        custom_domain = site["customDomain"]
        if custom_domain && custom_domain != ""
            domain = custom_domain
        else
            domain = "#{site["subdomain"]}.instatus.com"
        end

        name = site["name"]
        url = "https://#{domain}"
        safe_name = sanitized_name(name)

        definitions = [
            "let url = URL(string: \"#{url}\")!"
        ]

        definitions.unshift("let name = \"#{name}\"") if safe_name != name

        create_file "stts/Services/Instatus/#{safe_name}.swift", <<-INSTATUS
//
//  #{safe_name}.swift
//  stts
//

import Foundation

class #{safe_name}: InstatusService {
    #{definitions.join("\n    ")}
}
        INSTATUS

        return true
    end

    return false
end

def extract_statuspage(url)
    source = source_for("#{url}/api/v2/summary.json")
    return false unless source

    page = JSON.parse(source)["page"]
    id = page["id"]
    name = page["name"]
    safe_name = sanitized_name(name)

    definitions = [
        "let url = URL(string: \"#{url}\")!",
        "let statusPageID = \"#{id}\""
    ]

    definitions.unshift("let name = \"#{name}\"") if safe_name != name

    create_file "stts/Services/StatusPage/#{safe_name}.swift", <<-STATUSPAGE
//
//  #{safe_name}.swift
//  stts
//

import Foundation

class #{safe_name}: StatusPageService {
    #{definitions.join("\n    ")}
}
    STATUSPAGE

    true
end

def create_file(path, content)
    File.open(path, "w") do |f|
        f.write(content)
    end

    puts "Updated #{path}"

    # Open the existing Xcode project
    project = Xcodeproj::Project.open(@project_file)

    # Add a file to the project
    file_name = path.split("/").last
    group = project.main_group

    path.split("/")[0..-2].each do |group_name|
        group = group[group_name] if group[group_name]
    end

    if group.files.map(&:path).include?(file_name)
        puts "Skipped adding #{file_name} to project: already exists"
        return
    end

    # Get the file reference for the file to add
    file = group.new_file(file_name)

    # Add the file reference to the target
    main_target = project.targets.first
    main_target.add_file_references([file])

    # Sort it
    project.main_group.sort_recursively_by_type

    # Save it
    project.save

    puts "Added #{file_name} to project"
end

def sanitized_name(name)
    new_name = name.gsub(" & ", "And")
        .gsub("/", "")
        .gsub(":", "")
        .gsub("-", "")
        .gsub(".", "")
        .gsub("(", "")
        .gsub(")", "")
        .gsub("+", "")
        .gsub(",", "")

    words = new_name.split(" ").map do |word|
        # capitalize, first character only (CamelCase)
        word[0].upcase + word[1..-1]
    end

    words.join("")
end

def finish
    puts "Done!"

    puts "Running synx..."
    run_synx

    exit
end

def fail_params
    puts "Usage:"
    puts "bundle exec ruby extract.rb <url>"
    puts
    puts "Example:"
    puts "bundle exec ruby extract.rb https://status.notion.so/"
    exit 1
end

def fail_network
    puts "Could not check that link :("
    puts "Network issue or invalid link?"
    exit 1
end

def fail
    puts "No service found :("
    puts "Maybe create a ticket? https://github.com/inket/stts/issues"
    exit 1
end

def run_synx
    project = Synx::Project.open(@project_file)
    project.sync(
        prune: true,
        quiet: true,
        no_color: false,
        no_default_exclusions: false,
        no_sort_by_name: false,
        group_exclusions: []
    )
end

if Process.uid == 0
    puts "Cannot run extract script as root.".red
    exit 1
end

url = ARGV[0]
url = url.strip if url
fail_params unless url && url != ""

url = "https://#{url}" if URI.parse(url).scheme == nil
source = source_for(url)

fail_network unless source

finish if extract_instatus(source)
finish if extract_statuspage(url)

fail
