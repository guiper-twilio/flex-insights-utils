require 'gooddata'
require 'csv'
require 'optparse'

Thread.report_on_exception = false

Options = Struct.new(:name)

class Parser
  def self.parse(options)
    args = {:server => 'https://analytics.ytica.com'}

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: metrics_catalog.rb --username [username] --password [password] --server [server] --workspace_id [workspace_id]"

      opts.on("-u", "--username USERNAME", "Username to Flex Insights Environment") do |u|
        args[:user_name] = u
      end

      opts.on("-p", "--password PASSWORD", "password to Flex Insights Environment") do |p|
        args[:password] = p
      end

      opts.on("-s", "--server SERVER", "Server to login into Flex Insights - Defaults to analytics.ytica.com") do |s|
        args[:server] = 'https://analytics.ytica.com'
      end

      opts.on("-w", "--workspace WORKSPACE", "workspace to be catalogued") do |w|
        args[:workspace] = w
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
pp options

client = GoodData.connect(options[:user_name], options[:password], server: options[:server] )

project = client.projects(options[:workspace])
project_id = project.pid

control_center_uri =  GoodData::MdObject['aaqnTcK3gcCd', { client: client, project: project}].uri
pp control_center_uri

folder_cache = client.get(project.md['query'] + '/folders?type=metric')['query']['entries'].reduce({}) do |a, e|
  a[e['link']] = project.objects(e['link'])
  a
end


 CSV.open('out/' + project.pid + "_metrics.csv", 'wb',  :write_headers=> true,
         :headers => ["metric_folder","metric_title","metric_id", "metric_description",
                      "metric_expression" , "metric_creation_dt" , "used_by_control_center_dashboard", "metric_references"]) do |csv|
    data = project.metrics.pmap do |metric|
    # data = project.reports(4343).latest_report_definition.metrics.map do |metric|

    folder = metric.content.key?('folders') && metric.content['folders'].is_a?(Enumerable) && metric.content['folders'].first
    used_references = metric.usedby()
    used_on_control_center = used_references.any? {|h| h["link"] == control_center_uri}
    used_on_control_center_string = used_on_control_center ? "true" : "false"
    count = used_references.count()
    [ folder_cache[folder] && folder_cache[folder].title, metric.title, metric.obj_id,
      metric.summary, metric.pretty_expression, metric.created,  used_on_control_center_string , count ]
  end

  data.each do |m|
    csv << m
  end
  puts 'The CSV is ready!'
end