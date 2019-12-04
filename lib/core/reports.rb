require 'digest'
require_relative './reports.rb'
require_relative './metadata'

def pretty_print_report(h, opts)
  h.each do |k,v|
    # If v is nil, an array is being iterated and the value is k.
    # If v is not nil, a hash is being iterated and the value is v.
    #
    value = v || k

    if value.is_a?(Hash) || value.is_a?(Array)
      # puts "evaluating: #{value} recursively..."
      pretty_print_report(value,opts)
    else
      # MODIFY HERE! Look for what you want to find in the hash here
      # if v is nil, just display the array value
      # puts v ? "key: #{k} value: #{v}" : "array value #{k}"
      if k == "uri" or k == "value" or k == "element" or k == 'drillAcrossStepAttributeDF'
        if v =~ /elements/
          # puts "Match gdc"
          h[k] = ""
        elsif v =~ /^\/gdc\//
          h[k] =  GoodData::MdObject[v, opts].identifier
        end
      elsif k == "expression"
        h[k] = pretty_print_expression(v, opts)
      end
    end
  end
  return h
  #puts "After:"
  #pp h
end


def get_master_reports_and_simplified_expression(client, project_id_master)
  project_master = client.projects(project_id_master)


  reports = project_master.reports
  array_reports = reports.pmap do |report|
    #pp report.json
    #pp traverse( report.latest_report_definition.json['reportDefinition']['content'])
    {:report_identifier => report.identifier,
     :report_uri => report.uri,
     :report_title => report.title,
     :last_update => report.json['report']['meta']['updated'],
     :last_report_definition_identifier => report.latest_report_definition.json['reportDefinition']['meta']['identifier'],
     :pretty_expression => pretty_print_report( report.latest_report_definition.json['reportDefinition']['content'] , { client: client, project: project_master }),
     # 'expression_without_project_id' => remove_project_id_from_expression(report.expression, project_id_master )
    }
  end

  return array_reports
end




def compare_reports(client, master_reports, project_id_client)

  project_client = client.projects(project_id_client)

  result = []

  master_reports.pmap do |report_master|

    report_child = project_client.reports(report_master[:report_identifier])

    if report_child.nil?
      result << { :identifier => report_master[:report_identifier], :obj_title => report_master[:report_title], :project_hash => project_id_client,
                  :master_obj_id => report_master[:report_uri], # :master_pretty_expression => pretty_master_report,
                  :child_obj_id => '', # :child_pretty_expression => pretty_client_report
                  :difference_type => "object_missing_in_client_workspace"
      }
    else
      time_diff = Time.parse(report_child.json['report']['meta']['updated']) - Time.parse(report_master[:last_update])

      if( (time_diff <= -1000 or time_diff >= 1000 ) )

        pretty_client_report = pretty_print_report(report_child.latest_report_definition.json['reportDefinition']['content'],{ client: client, project: project_client } )
        pretty_master_report = report_master[:pretty_expression].deep_stringify_keys

        if(pretty_client_report != pretty_master_report)
          # It is different!
          puts 'Different!'
          pp pretty_client_report
          pp pretty_master_report
          result << { :identifier => report_master[:report_identifier], :obj_title => report_master[:report_title], :project_hash => project_id_client,
                      :master_obj_id => report_master[:report_uri], # :master_pretty_expression => pretty_master_report,
                      :child_obj_id => report_child.uri, # :child_pretty_expression => pretty_client_report
                      :difference_type => "object_differs_from_template"
          }
        end
      end
    end
  end
  return result
end




def compare_reports_v2(client, master_reports, project_id_client)



  project_client = client.projects(project_id_client)

  if project_client.state.to_s != 'enabled'
    return []
  end

  report_identifiers = master_reports.map { |rep| rep[:report_identifier]  }
  definition_identifiers = master_reports.map { |rep| rep[:last_report_definition_identifier] }

  # Get Uris using Batch mode
  report_uris = map_identifiers_to_uri(report_identifiers, client, project_client)
  definitions_uris = map_identifiers_to_uri(definition_identifiers, client, project_client)

  report_uris = report_uris.map { |obj| obj['uri'] }
  definitions_uris = definitions_uris.map { |obj| obj['uri'] }

  # Change to Optimized Format
  report_objects = get_multiple_objects_with_uri(report_uris, client, project_client)
  definition_objects = get_multiple_objects_with_uri(definitions_uris, client, project_client)
  # Get Objects using batch Mode

  child_reports = report_objects.map do |child_obj|
    latest_definition_uri = child_obj['content']['definitions'].last
    definition = definition_objects.find { |d| d['uri'] == latest_definition_uri}
    content_definition = definition.nil? ? '' : definition['content']

    {:report_identifier => child_obj['identifier'],
     :report_uri => child_obj['uri'],
     :report_title => child_obj['title'],
     :last_update => child_obj['updated'],
     :last_report_definition_uri =>  latest_definition_uri,
     :expression => content_definition.to_s,
     :pretty_expression => content_definition.to_s
    }
  end

  # Get underlying uris used by any report
  underlying_uris = []
  child_reports.each do |child_report|
    new_uris = get_uris(child_report[:expression], true)
    underlying_uris = underlying_uris.concat(new_uris)
  end

  #Dedup and remove
  underlying_uris.uniq!()

  mapping = map_uri_to_identifiers(underlying_uris, client, project_client)


  child_reports.each_with_index do |child_report, k |
    expression = child_report[:pretty_expression]
    uris = get_uris(expression, false)
    # Elements must be dealt first
    uris = uris.sort_by { | u | - u.length  }

    uris.each do |uri|
      if uri =~ /elements/
        expression.gsub!( uri, '')
      else
        map = mapping.find { |m| m["uri"] == uri}
        unless map.empty?
          expression.gsub!(map["uri"], map["identifier"])
        end
      end
    end
    child_reports[k][:pretty_expression] = expression
  end

  result = []

  master_reports.map do |report_master|


    report_child = child_reports.find{|report| report[:report_identifier] ==  report_master[:report_identifier]}


    if report_child.nil?
      result << { :identifier => report_master[:report_identifier], :obj_title => report_master[:report_title], :project_hash => project_id_client,
                  :master_obj_id => report_master[:report_uri], # :master_pretty_expression => pretty_master_report,
                  :child_obj_id => '', # :child_pretty_expression => pretty_client_report
                  :difference_type => "object_missing_in_client_workspace"
      }
    else

      pretty_client_report = report_child[:pretty_expression]

      pretty_master_report = report_master[:pretty_expression].deep_stringify_keys.to_s


      if(pretty_client_report != pretty_master_report)
        # It is different!

        latest_definiton = GoodData::MdObject[report_child[:last_report_definition_uri], { client: client, project: project_client} ]
        pretty_client_report = pretty_print_report(latest_definiton.json['reportDefinition']['content'],{ client: client, project: project_client } ).deep_stringify_keys.to_s

        if report_master[:report_identifier] == '' or report_master[:report_identifier]   == 'abPBFm6ZgjV4'
          pp report_master[:pretty_expression].deep_stringify_keys
          pp pretty_print_report(latest_definiton.json['reportDefinition']['content'],{ client: client, project: project_client } ).deep_stringify_keys
        end

        result << { :identifier => report_master[:report_identifier], :obj_title => report_master[:report_title], :project_hash => project_id_client,
                    :master_obj_id => report_master[:report_uri], :master_pretty_expression => Digest::MD5.hexdigest(pretty_master_report),
                    :child_obj_id => report_child[:report_uri], :child_pretty_expression => Digest::MD5.hexdigest(pretty_client_report),
                    :difference_type => "object_differs_from_template"
        }
      end
    end
  end
  return result
end

