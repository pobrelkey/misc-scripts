#!/usr/bin/env ruby

#
#  Script to help you maintain a log of when an event occurs.
#  (For example, if you're gathering evidence for a noise complaint
#  against a neighboring property.)
#

require 'date'
require 'fileutils'
require 'json'
require 'optparse'
require 'optparse/date'


Event = Struct.new(:begins, :ends, :message)

def write_log(f, events)
	last = DateTime.jd(0)
	events.sort_by{|x| x.begins.to_time.to_f }.each do |i|
		if i.begins.jd != last.jd && i.begins.year != last.year
			f << i.begins.strftime("\n%Y-%m-%d: %H%M")
		elsif i.begins.jd != last.jd && i.begins.month != last.month
			f << i.begins.strftime("\n-%m-%d: %H%M")
		elsif i.begins.jd != last.jd && i.begins.mday != last.mday
			f << i.begins.strftime("\n-%d: %H%M")
		else
			f << i.begins.strftime(' %H%M')
		end
		f << i.ends.strftime('-%H%M') if !i.ends.nil?
		if i.message =~ /^[^\r\n()"\\]+$/
			f << " (#{i.message})"
		elsif !i.message.nil?
			f << " (#{JSON.dump(i.message)})"
		end
		last = i.begins
	end
	f << "\n"
end

def read_log(f)
	events = []
	last = DateTime.jd(0)
	f.each_line do |line|
		year, month, day = last.year, last.month, last.mday
		if line.sub!(/^(?:(20\d\d)?-(0[1-9]|1[012]))?-(0[1-9]|[12]\d|3[01]):/, '')
			year, month, day = ($1 || year).to_i, ($2 || month).to_i, ($3 || day).to_i
		end
		line.scan(/ ([01]\d|2[0-3])([0-5]\d)(?:-([01]\d|2[0-3])([0-5]\d))?(?: \((?:([^\r\n()"\\]+)|("(?:[^"\\]|\\.)+"))\))?/) do
			begins = DateTime.new(year, month, day, $1.to_i, $2.to_i)
			ends = $3.nil? ? nil : DateTime.new(year, month, day, $3.to_i, $4.to_i)
			ends += 1 if !ends.nil? && ends < begins
			message = $6.nil? ? $5 : JSON.load($6)
			events << Event.new(begins, ends, message)
		end
	end
	return events.sort_by{|x| x.begins.to_time.to_f }
end


REMIND_DEFAULT = 5
DEFAULT_FILE = 'default'
FILENAME_TEMPLATE = '~/.local/share/shaddap_rb/%s.txt'

event_time = DateTime.now()
show_fn = cont = undo = false
filename = count_days = detail_days = remind_mins = message = nil
OptionParser.new do |op|
	op.on('-l', '--log FILE', String, 'Log events to FILE (default: %s)' % (FILENAME_TEMPLATE % DEFAULT_FILE)) {|x| filename = x }
	op.on('-p', '--path', 'print full Path to file where we record events, then exit') { show_fn = true }
	op.on('-m', '--message MSG', String, 'add Message MSG to log entry') {|x| message = x }
	op.on('-t', '--time DATETIME', DateTime, 'event happened at DATETIME') {|x| event_time = x }
	op.on('-c', '--continue', 'last event is Continuing') { cont = true }
	op.on('-u', '--undo', 'Undo recording of last event') { undo = true }
	op.on('-d', '--days DAYS', Float, 'show event count over past DAYS Days') {|x| count_days = x }
	op.on('-D', '--detailed DAYS', Float, 'show Detailed report of events over past DAYS days') {|x| detail_days = x }
	op.on('-r', '--remind [MINS]', Float, 'Remind in MINS minutes (pause then play a tone; default: %d)' % REMIND_DEFAULT) {|x| remind_mins = x.nil? ? REMIND_DEFAULT : x }
end.parse!

filename = DEFAULT_FILE if filename.nil?
filename = FILENAME_TEMPLATE % filename if filename !~ /\//
filename.sub!(/^~/,ENV['HOME'])
if show_fn
	puts(filename)
	exit(0)
end
FileUtils.mkdir_p(File.dirname(filename))
events = File.exist?(filename) ? File.open(filename,'r'){|f| read_log(f) } : []

if !detail_days.nil? || !count_days.nil?
	days == detail_days.nil? ? count_days : detail_days
	events.select!{|x| x.begins >= event_time - days && x.begins < event_time }
	write_times(STDOUT, events) if !detail_days.nil?
	puts(events.size)
else
	event_time = DateTime.new(event_time.year, event_time.month, event_time.mday, event_time.hour, event_time.minute)  # strip offset
	if cont
		events.last.ends = event_time
		events.last.message = [events.last.message, message].compact.join('; ') if !message.nil?
	elsif undo
		puts('deleting last event @ %s' % events.pop.begin.strftime('%Y-%m-%d %H:%M'))
	else
		puts('recording event @ %s' % event_time.strftime('%Y-%m-%d %H:%M'))
		events << Event.new(event_time, nil, message)
	end
	File.open(filename,'w') {|f| write_log(f, events) }
	if remind_mins
		sleep(remind_mins * 60)
		system('play -qn synth 0.6 sine 1600 pad 1@0 0.2@0.2 0.2@0.4 gain -3')  # I've started so I'll finish...
	end
end

