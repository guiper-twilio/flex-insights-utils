require 'gooddata'
require 'prettyprint'
require 'optparse'
require "json"
require_relative('lib/core/metadata')

def clone_kpi_dashboard_in_same_workspace(obj, opts)

  client = opts[:client]
  project_id = opts[:project].pid

  case obj['category']
  when "analyticalDashboard"
    all_objects = get_object_dependencies(obj['obj_id'], opts[:client], opts[:project],  "filterContext,kpi", 1 , false )

    mapping = all_objects.map do |report|
      clone_kpi_dashboard_in_same_workspace(report, opts)
    end

    obj['full_json']['analyticalDashboard']['meta'].delete('uri')
    obj['full_json']['analyticalDashboard']['meta'].delete('identifier')
    obj['full_json']['analyticalDashboard']['meta']['title'] = obj['title'] + " Ruby Duplicate"
    obj['full_json']['analyticalDashboard']['meta'].delete('locked')

    target_json_string = obj['full_json'].to_s

    mapping.each do |map|
      target_json_string.gsub!(map['original_uri'], map['cloned_uri'])
    end

    target_json = eval( target_json_string )

    res = client.post "/gdc/md/#{project_id}/obj" , target_json

    pp res['uri']


  when "kpi"

    obj['full_json']['kpi']['meta'].delete('uri')
    obj['full_json']['kpi']['meta'].delete('locked')
    obj['full_json']['kpi']['meta'].delete('identifier')
    obj['full_json']['kpi']['meta']['title'] = obj['title']



    res = client.post "/gdc/md/#{project_id}/obj" , obj['full_json']

    return {'original_uri'=> obj['uri'] , 'cloned_uri'=> res['uri']}


  when "filterContext"


    # Delete Links, not needed
    # Delete URI (obj_id) so a new one is created
    obj['full_json']['filterContext']['meta'].delete('uri')
    obj['full_json']['filterContext']['meta'].delete('locked')
    obj['full_json']['filterContext']['meta'].delete('identifier')

    res = client.post "/gdc/md/#{project_id}/obj" , obj['full_json']

    return {'original_uri'=> obj['uri'] , 'cloned_uri'=> res['uri']}

  end

  return obj
end


Options = Struct.new(:name)

class Parser
  def self.parse(options)
    args = {:server => 'https://analytics.ytica.com'}

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: copy_objects_old.rb --username [username] --password [password] --server [server] --obj_id [obj_id]"

      opts.on("-u", "--username USERNAME", "Username to Flex Insights Environment") do |u|
        puts u
        args[:user_name] = u
      end

      opts.on("-p", "--password PASSWORD", "password to Flex Insights Environment") do |p|
        args[:password] = p
      end

      opts.on("-s", "--server SERVER", "Server to login into Flex Insights - Defaults to analytics.ytica.com") do |s|
        args[:server] = s
      end

      opts.on("-w", "--workspace WORKSPACE", "workspace to be catalogued") do |w|
        args[:workspace] = w
      end

      opts.on("-k", "--kpi KPI", "KPI Dashboard to Duplicate and Unlock - In the identifier format ab7ZNFV8eyr1") do |c|
        args[:kpi] = c
      end

      opts.on("-h", "--help", "Prints this help") do
        puts opts
        exit
      end
    end

    opt_parser.parse!(options)
    return args
  end
end


options = Parser.parse(ARGV)


client = GoodData.connect(options[:user_name], options[:password], server: options[:server] )
project = client.projects( options[:workspace] )


obj_uri = map_identifiers_to_uri([ options[:kpi] ],client, project)

object = get_single_object_with_uri( obj_uri[0]['uri'], client)

if object['category'] == 'analyticalDashboard'
  clone_kpi_dashboard_in_same_workspace(object, {client: client, project: project})
else
  raise "Object is not a KPI Dashboard"
end