require 'json'
require 'ostruct'
require 'time'
require 'open-uri'
require 'csv'

unless ENV['TOKEN'] && ENV['PROJECT_ID'] 
  puts "TOKEN and PROJECT_ID required!" 
  exit
else
  TOKEN      = ENV['TOKEN']
  PROJECT_ID = ENV['PROJECT_ID']
end

SEC_TO_DAYS_MULTIPLIER = 24 * 60 * 60

module HttpHelper

  def fetch_http(url, headers = {})
    headers.merge!("X-TrackerToken" => TOKEN)
    response = open(url, headers).read
    JSON.parse(response)
  rescue => e
    puts "Failed to fetch #{url} with headers #{headers.inspect}:"
    puts e.message
  end

end

class StoryData

  extend HttpHelper

  def self.request(story_id)
    url = "https://www.pivotaltracker.com/services/v5/projects/#{PROJECT_ID}/stories/#{story_id}"
    fetch_http(url)
  end

  def self.get(story_id)
    request(story_id)
  end

end

class StoryActivityData
  extend HttpHelper

  def self.request(story_id)
    url = "https://www.pivotaltracker.com/services/v5/projects/#{PROJECT_ID}/stories/#{story_id}/activity"
    fetch_http(url)
  end

  def self.get(story_id)
    data = request(story_id)
    p data
    out  = OpenStruct.new(lead_time: nil, cycle_time: nil, accepted: false)

    # created
    # TODO find the moment when story was selected to be developed. "moved and scheduled?"
    added_data = data.find { |change| change["highlight"] == "added" }
    if added_data 
      out.added_at = Time.parse(added_data["occurred_at"])
      out.added_by = added_data["performed_by"]["name"]
    end

    # started
    start_data = data.select { |change| change["highlight"] == "started" }.last
    if start_data
      out.started_at = Time.parse(start_data["occurred_at"])
      out.started_by = start_data["performed_by"]["name"]
    end

    # accepted
    accept_data = data.select { |change| change["highlight"] == "accepted" }.first
    if accept_data
      out.accepted_at = Time.parse(accept_data["occurred_at"])
      out.accepted_by = accept_data["performed_by"]["name"]

      out.accepted   = true
      if out.started_at
        out.cycle_time = ((out.accepted_at - out.started_at) / SEC_TO_DAYS_MULTIPLIER).round
      end
      if out.added_at
        out.lead_time  = ((out.accepted_at - out.added_at) / SEC_TO_DAYS_MULTIPLIER).round 
      end
    end

    out
  end
end

class ProjectStories
  
  extend HttpHelper
  
  def self.request(project_id, params)
    url = "https://www.pivotaltracker.com/services/v5/projects/#{project_id}/stories"
    query_string = params.map { |k, v| "#{k}=#{URI.escape(v.to_s)}"}.join("&") 
    url << "?"
    url << query_string
    fetch_http(url)
  end

  def self.get(project_id)    
    # type: feature, Bug, Chore or Release.
    # state: unscheduled, unstarted, started, finished, delivered, accepted, or rejected
    params = { filter: "created_after:08/01/2013", limit: 20 }
    stories = request(project_id, params)
    out = []
    #features = data.select { |story| story['story_type'] == "bug"}
    stories.each do |story|
      out << OpenStruct.new(id: story["id"], created_at: story["created_at"], estimate: story["estimate"], name: story["name"])
    end
    out
  end
end

stories = ProjectStories.get(PROJECT_ID)
stories.each do |story|
  p story.id
  activity = StoryActivityData.get(story.id)
  p activity
  activity.marshal_dump.each do |key, value|
    story.send("#{key}=", value)
  end
end

csv_fields = %w(id name estimate accepted added_at started_at accepted_at lead_time cycle_time)
CSV.open("pivotal_times_bugs_2.csv", 'wb', col_sep: ";", headers: stories.first.marshal_dump.keys, write_headers: true) do |csv|
  stories.each do |story|
    row = csv_fields.map { |field| story.send(field) }
    csv << row
  end
end



# add lead and cycle time to csv
# get all bug data into CSV reliably (older data, stories which have no accepted_at, etc.)
# measure lead time by time scheduled