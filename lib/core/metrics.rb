require_relative './metadata'



def pretty_print_expression(expression, opts = { client: GoodData.connection, project: GoodData.project })
  temp = expression.dup
  pairs = get_uris(expression).pmap do |uri|
    if uri =~ /elements/
      begin
        #sample =  GoodData::Attribute.find_element_value(uri, opts)
        # puts sample
        # Fix Me Later!
        ['element', uri, ""]
      rescue Exception
        ['element', uri, '(empty value)']
      end
    else
      ['object', uri,  GoodData::MdObject[uri, opts].identifier]
    end
  end
  pairs.sort_by! { |p| p[0] }
  pairs.each do |el|
    uri = el[1]
    obj = el[2]
    temp.gsub!(uri, obj)
  end
  temp
end


def get_master_metrics_and_simplified_expression(client, project_id_master)
  project_master = client.projects(project_id_master)


  metrics = project_master.metrics
  metrics = metrics.pmap do |metric|
    {:metric_identifier => metric.identifier,
     :metric_uri => metric.uri,
     :metric_title => metric.title,
     :last_update => metric.json['metric']['meta']['updated'],
     :pretty_expression => pretty_print_expression(metric.expression, { client: client, project: project_master }),
     :expression_without_project_id => remove_project_id_from_expression(metric.expression, project_id_master )
    }
  end

  return metrics
end




def compare_metrics_v2(client, master_metrics, project_id_client)

  project_client = client.projects(project_id_client)

  if project_client.state.to_s != 'enabled'
    return []
  end

  result = []

  master_metrics.pmap do |metric_master|



    metric_child = project_client.metrics(metric_master[:metric_identifier])


    if metric_child.nil?
      result << { :identifier => metric_master[:metric_identifier], :obj_title => metric_master[:metric_title], :project_hash => project_id_client,
                  :master_obj_id => metric_master[:metric_uri], :master_pretty_expression => '',
                  :child_obj_id => '', :child_pretty_expression => '' ,
                  :difference_type => "object_missing_in_client_workspace"

      }
    else
      time_diff = Time.parse(metric_child.json['metric']['meta']['updated']) - Time.parse(metric_master[:last_update])

      if( (time_diff <= -1000 or time_diff >= 1000 ) and (metric_master[:expression_without_project_id] !=  remove_project_id_from_expression(metric_child.expression, project_id_client )) )
        # Expressions are different, let's dig in and check more details
        # First, replace onbj_id with identifiers and remove the attribute elements
        pretty_parent = metric_master[:pretty_expression]
        pretty_child  = pretty_print_expression(metric_child.expression, { client: client, project: project_client })

        # Do another check
        if(pretty_child != pretty_parent)
          # They must be different!
          result << { :identifier => metric_master[:metric_identifier], :obj_title => metric_master[:metric_title], :project_hash => project_id_client,
                      :master_obj_id => metric_master[:metric_uri], :master_pretty_expression => pretty_parent,
                      :child_obj_id => metric_child.uri, :child_pretty_expression => pretty_child ,
                      :difference_type => "object_differs_from_template"

          }
        end
      end
    end
  end
  return result
end




def compare_metrics_v3(client, master_metrics, project_id_client)

  project_client = client.projects(project_id_client)

  result = []

  identifiers = master_metrics.map { |metric| metric[:metric_identifier]  }

  # Get Uris using Batch mode
  uris = map_identifiers_to_uri(identifiers, client, project_client)
  uris = uris.map { |obj| obj['uri'] }


  objects = get_multiple_objects_with_uri(uris, client, project_client)
  # Change to optimized format

  child_metrics = objects.map do |child_metric|
    {:metric_identifier => child_metric['identifier'],
     :metric_uri => child_metric['uri'],
     :metric_title => child_metric['title'],
     :last_update => child_metric['updated'],
     :expression => child_metric['content']['expression'],
     :expression_without_project_id => remove_project_id_from_expression(child_metric['content']['expression'], project_id_client )
    }
  end

  # Get underlying uris used by any metric
  underlying_uris = []
  child_metrics.each do |child_metric|
    new_uris = get_uris(child_metric[:expression], true)
    underlying_uris = underlying_uris.concat(new_uris)
  end

  #Dedup and remove
  underlying_uris.uniq!()

  mapping = map_uri_to_identifiers(underlying_uris, client, project_client)


  child_metrics.each_with_index do |child_metric, k |
    expression = child_metric[:expression]
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
    child_metrics[k][:pretty_expression] = expression
  end

  master_metrics.map do |metric_master|

    metric_child = child_metrics.find{|metric| metric[:metric_identifier] ==  metric_master[:metric_identifier]}

    if metric_child.nil?
      result << { :identifier => metric_master[:metric_identifier], :obj_title => metric_master[:metric_title], :project_hash => project_id_client,
                  :master_obj_id => metric_master[:metric_uri], :master_pretty_expression => '',
                  :child_obj_id => '', :child_pretty_expression => '' ,
                  :difference_type => "object_missing_in_client_workspace"

      }
    else
      if metric_child[:pretty_expression] != metric_master[:pretty_expression]
        # They must be different!
        result << { :identifier => metric_master[:metric_identifier], :obj_title => metric_master[:metric_title], :project_hash => project_id_client,
                    :master_obj_id => metric_master[:metric_uri], :master_pretty_expression => metric_master[:pretty_expression],
                    :child_obj_id => metric_child[:metric_uri], :child_pretty_expression => metric_child[:pretty_expression] ,
                    :difference_type => "object_differs_from_template"

        }
      end
    end
  end
  return result
end

