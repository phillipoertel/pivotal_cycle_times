require 'csv'
require 'time'

out = {}
(0..55).each { |i| out[i] = {opened: 0, closed: 0 }}
p out
csv = CSV.read('pivotal_times_bugs_2.csv', headers: true, col_sep: ';')
csv.each do |row|

  added = Time.parse(row["added_at"]) rescue nil

  week = added.strftime("%W").to_i
  out[week][:opened] += 1

  accepted = Time.parse(row["accepted_at"]) rescue nil
  if (accepted)
    week = accepted.strftime("%W").to_i
    out[week][:closed] += 1
  end
end

CSV.open("bugs_opened_closed_2.csv", "wb", col_sep: ";") do |csv|
  out.each do |key, value|
    array = [key, value[:opened], value[:closed]] 
    csv << array
  end
end