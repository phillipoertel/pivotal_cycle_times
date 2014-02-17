require 'json'
require 'ostruct'
require 'time'
require 'open-uri'

TOKEN      = ENV['TOKEN']
PROJECT_ID = 568445
SEC_TO_DAYS_MULTIPLIER = 24 * 60 * 60

module Helper

  def fetch_http(url, headers = {})
    headers.merge!("X-TrackerToken" => TOKEN)
    response = open(url, headers).read
    JSON.parse(response)
  end

end

class StoryData

  extend Helper

  def self.request(story_id)
    url = "https://www.pivotaltracker.com/services/v5/projects/#{PROJECT_ID}/stories/#{story_id}"
    fetch_http(url)
  end

  def self.get(story_id)
  end

end

class StoryActivityData
  extend Helper

  def self.request(story_id)
    url = "https://www.pivotaltracker.com/services/v5/projects/#{PROJECT_ID}/stories/#{story_id}/activity"
    fetch_http(url)
  end

  def self.get(story_id)
    data = request(story_id)
    out  = OpenStruct.new(lead_time: nil, cycle_time: nil, accepted: false)

    # created
    # TODO find the moment when story was selected to be developed. "moved and scheduled?"
    added_data = data.find { |change| change["highlight"] == "added" }
    out.added_at = Time.parse(added_data["occurred_at"])
    out.added_by = added_data["performed_by"]["name"]

    # started
    start_data = data.find { |change| change["highlight"] == "started" }
    out.started_at = Time.parse(start_data["occurred_at"])
    out.started_by = start_data["performed_by"]["name"]

    # accepted
    accept_data = data.find { |change| change["highlight"] == "accepted" }
    if accept_data
      out.accepted_at = Time.parse(accept_data["occurred_at"])
      out.accepted_by = accept_data["performed_by"]["name"]

      out.accepted   = true
      out.cycle_time = ((out.accepted_at - out.started_at) / SEC_TO_DAYS_MULTIPLIER).round
      out.lead_time  = ((out.accepted_at - out.added_at) / SEC_TO_DAYS_MULTIPLIER).round 
    else
    end

    out
  end
end

class ProjectStories
  
  extend Helper
  
  def self.request(project_id, params)
    url = "https://www.pivotaltracker.com/services/v5/projects/#{project_id}/stories"
    query_string = params.map { |k,v| "#{k}=#{v}"}.join("&") 
    url << "?"
    url << query_string
    fetch_http(url)
  end

  def self.get(project_id)
    params = { with_state: "accepted", created_after: Date.new(2013, 10, 1).iso8601 + "T00:00:00", limit: 1_000 }
    data = request(project_id, params)
    out = []
    features = data.select { |story| story['story_type'] == "feature"}
    features.each do |feature|
      out << OpenStruct.new(id: feature["id"], created_at: feature["created_at"], estimate: feature["estimate"])
    end
    out
  end
end

stories = ProjectStories.get(PROJECT_ID)
stories.each do |story|
  activity = StoryActivityData.get(story.id)
  activity.marshal_dump.each do |key, value|
    story.send("#{key}=", value)
  end
end

puts CSV.dump(stories.map { |story| story.marshal_dump })