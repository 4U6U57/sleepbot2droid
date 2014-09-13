require 'csv'

# Parses CSV-exported data from SleepBot
def parse_export(row)
	# Parse the wake up date
	date_to = row[0].split('/')
	date_to = Time.new(2000 + date_to[2].to_i, date_to[1], date_to[0])
	
	# Parse the wake up/sleep times
	time_from = row[1].split(':')
	time_to = row[2].split(':')
	time_from = Time.new(1970, 1, 1, time_from[0], time_from[1])
	time_to = Time.new(1970, 1, 1, time_to[0], time_to[1])

	# Check whether we advanced a day. Our start date is one day before in that case.
	is_from_prev_day = time_to < time_from
	
	# Construct the sleep date/time and wake up date/time
	time_to = Time.new(date_to.year, date_to.mon, date_to.day, time_to.hour, time_to.min)
	time_from = Time.new(date_to.year, date_to.mon, date_to.day, time_from.hour, time_from.min)
	time_from -= 1 * 24 * 60 * 60 if is_from_prev_day
  
	hours = row[3].to_f
	notes = row[4]
  
	[time_from, time_to, hours, 0, notes]
end

# Parses raw SQLite database dumps from the SleepBot app.
def parse_raw(row)
  # Java timestamps: Unix timestamps, with ns resolution
	timestamp_from = row[1].to_f / 1000.0
	timestamp_to = row[2].to_f / 1000.0
	hours = (timestamp_to - timestamp_from) / 60 / 60
	
	notes = row[3]
	rating = row[10]
  
	[Time.at(timestamp_from), Time.at(timestamp_to), hours, rating.to_i, notes || '']
end

# Formates Date/Time objects in Sleep as Android format
def sleepandroid_time(time)
	'%.2d. %.2d. %d %d:%.2d' % [time.day, time.mon, time.year, time.hour, time.min]
end

results = []
parser = :parse_export

# Load the import file.
CSV.foreach('sleepbot-raw.csv') do |row|
	date_to = row[0]
	
	# Detect the type of the file we are importing.
	parser = :parse_raw if date_to == '_id'
	next if date_to == 'Date' || date_to == '_id'
	
	a = send(parser, row)
	puts a.inspect
	results << a
end

# Write the converted file in the Sleep as Android format.
CSV.open('sleepbot-converted.csv', 'wb') do |csv|
	results.each do |result|
		csv << ['Id',                  'Tz',             'From',                       'To',                         'Sched',                      'Hours',   'Rating',  'Comment', 'Framerate', 'Snore', 'Noise', 'Cycles', 'DeepSleep', 'LenAdjust', 'Geo', '%d:%d' % [result[1].hour, result[1].min], 'Event',                                      'Event']
		csv << [result[0].to_i * 1000, 'Asia/Singapore', sleepandroid_time(result[0]), sleepandroid_time(result[1]), sleepandroid_time(result[1]), result[2], result[3], result[4], 10000,       -1,      -1,      -1,       -1,          0,           '',    0,                                         'DEEP_START-' + (result[0].to_i * 1000).to_s, 'DEEP_END-' + (result[0].to_i * 1000).to_s]
	end
end
