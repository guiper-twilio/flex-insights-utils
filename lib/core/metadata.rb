
def get_uris(a_maql_string, remove_elements_after_uri = false)
  uris = []
  uris = a_maql_string.scan(/(\/gdc\/md\/\w*\/obj\/\d*(?>\/elements\?id=\d*)?)+/).flatten || []
  if remove_elements_after_uri
    uris = uris.map{ |c| c.gsub!(/\/elements\?id=\d*$/, '') || c }
  end
  uris.uniq!
  uris
end

def get_obj_id_from_uri(uri)
  obj_id =  uri.scan(/\/obj\/(\d*)/)
  return obj_id[0][0]
end

def parse_gooddata_format_to_optimized_format(obj)
  ret = {}
  obj.each do |k, v|
    ret = v['meta'].dup
    ret['full_json'] = obj
    ret['obj_id'] = get_obj_id_from_uri(ret['uri'])
    ret['content'] = v['content']
  end
  return ret
end

# All objects is in optimized format
def find_element_value(element, element_link, client)
  element_id = element.match(/\?id=(\d+)/)[1]

  result = client.get(element_link + "/?id=#{element_id}")
  items = result['attributeElements']['elements']
  if items.empty?
    return "ERROR_NOT_FOUND_GDC_FLEX"
  else
    items.first['title']
  end
end

def map_identifiers_to_uri(identifiers, client, project_client)
  project_id_client = project_client.pid
  mapping = client.post "/gdc/md/#{project_id_client}/identifiers" , {'identifierToUri' => identifiers}
  #uris = GoodData::MdObject.identifier_to_uri( { client: client, project: project_client } , *identifiers )
  return mapping["identifiers"] - [nil, '']
end

def map_uri_to_identifiers(uris, client, project_client)
  project_id_client = project_client.pid
  mapping = client.post "/gdc/md/#{project_id_client}/identifiers" , {'uriToIdentifier' => uris}
  return mapping["identifiers"] - [nil, '']
end

def get_multiple_objects_with_uri(uris, client, project_client)
  project_id_client = project_client.pid
  res = []
  unless uris.nil?
    uris -= [nil, '']
    uris.each_slice(50) do |uris_50|
      local_res = client.post "/gdc/md/#{project_id_client}/objects/get" , {'get' => {'items' => uris_50 }}
      res = res.concat(local_res['objects']['items'])
    end
  end
  full_objs = res.pmap do |obj|
    parse_gooddata_format_to_optimized_format(obj)
  end
  full_objs
end

def get_single_object_with_uri(uri, client)
  res = client.get uri
  return parse_gooddata_format_to_optimized_format(res)
end


def get_object_dependencies(object, client, project_client,types = "", nearest = 0, include_only_custom = true)
  project_id_client = project_client.pid
  res = client.get "/gdc/md/#{project_id_client}/using2/#{object}?types=#{types}&nearest=#{nearest}"
  results = res["entries"] - [nil, '']

  uris = results.map{ |obj| obj['link']}

  # Get the entire objects. We need
  full_objs = get_multiple_objects_with_uri(uris, client, project_client)

  if include_only_custom
    # Remove objects where the author is "admins@ytica.com"
    full_objs.delete_if{ |obj| obj['author'] == '/gdc/account/profile/6bad35e2425f2d7ef6f9b5f80e3c0f03' and obj['tags'] =~ /_lcm_managed_object/ }
  end

  return full_objs
end

def remove_project_id_from_expression(expression, project_id)
  expression = expression.gsub(project_id, "")
  return expression.gsub(/\/elements?id=\d+/, "").strip()
end

def clear_caches(client, project_id)
  client.post "/gdc/md/#{project_id}/clearCaches",  { 'clearCaches'  => {' hours' => 0, 'xcaches' => true, 'qtcaches' => true} }
end

def save_object_ensuring_identifier(obj, identifier, client, project)
  project_id = project.pid

  map = map_identifiers_to_uri( [ identifier ] , client, project )
  if map.empty?
    res = client.post "/gdc/md/#{project_id}/obj" , obj
    # Save a second time to ensure identifier is maintained over workspaces! Important
    res = client.post res['uri'], obj
    list = get_multiple_objects_with_uri( [ res['uri'] ] , client, project)
    if list[0]['identifier'] != identifier
      raise 'Cannot Continue, object identifier is different'
    end
  else
    # Obj Exists, let's override it!
    existing_obj = map[0]
    res = client.post existing_obj['uri'] , obj
  end

  return res['uri']
end