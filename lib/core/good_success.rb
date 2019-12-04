require 'gooddata'
require 'csv'
require 'prettyprint'

class GoodSuccess

  def initialize(username, password)
    @client = GoodData.connect(username, password,  server: 'https://engagement.gooddata.com' )
    @project_goodsuccess = @client.projects('d0yaqkwwo0ej2fyai2l2t9m4e4bjggsw');
  end

  def get_top_usage_workspaces(howmany = 999)
    result = @project_goodsuccess.reports(121703).latest_report_definition.execute
    return result.without_top_headers.to_a.first(howmany)
  end

end