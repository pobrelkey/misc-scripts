#!/usr/bin/env bash

#
# Go through any git repositories under the current directory,
# dump out a CSV of "interesting" commits.
#
# TODO: nice arg parsing - for now set params using env vars:
#    AUTHOR_REGEXP - regexp to match against author name+email
#    COMMENT_REGEXP - regexp to match against comment text
#    DATE_MIN - earliest date/time for any commits
#    DATE_MAX - latest date/time for any commits
#

find . -name .git \
	| (
		while 
			read GITDIR && [ -n "${GITDIR}" ]
		do
			REPODIR="$(dirname "${GITDIR}")"
			pushd "${REPODIR}" >/dev/null
			GITURL="$(git remote get-url origin 2>/dev/null)"
			if [ -n "${GITURL}" ]
			then
				echo "$(echo -n "${GITURL}" | basenc --base16 -w 0)|$(echo -n "${REPODIR}" | basenc --base16 -w 0)"
			fi
			popd >/dev/null
		done
	) \
	| parallel --will-cite -I{} --group --colsep '\|' \
		sh -c "'cd \"\$(perl -e \"print pack(\\\"H*\\\",\\\"{2}\\\")\")\" && git log | perl -ne \"print ; print \\\"Repository: \\\".pack(\\\"H*\\\",\\\"{1}\\\").\\\"\\\n\\\" if /^commit [0-9a-f]+$/\" ; echo'" \
	| ruby -e '
		require "csv"
		require "stringio"
		require "date"

		Commit = Struct.new(:date,:commit,:repos,:author,:comment)

		AUTHOR_REGEXP  = ENV["AUTHOR_REGEXP"].nil? ? nil : Regexp.compile(ENV["AUTHOR_REGEXP"])
		COMMENT_REGEXP = ENV["COMMENT_REGEXP"].nil? ? nil : Regexp.compile(ENV["COMMENT_REGEXP"])
		DATE_MIN       = ENV["DATE_MIN"].nil? ? nil : DateTime.parse(ENV["DATE_MIN"])
		DATE_MAX       = ENV["DATE_MAX"].nil? ? nil : DateTime.parse(ENV["DATE_MAX"])

		def is_match(commit)
			return (
				(AUTHOR_REGEXP.nil? || commit.author =~ AUTHOR_REGEXP) &&
				(COMMENT_REGEXP.nil? || commit.comment =~ COMMENT_REGEXP) &&
				(DATE_MIN.nil? || commit.date >= DATE_MIN) &&
				(DATE_MAX.nil? || commit.date <= DATE_MAX)
			)
		end

		all = []
		c = Commit.new()
		STDIN.each_line do |line|
			if line =~ /^commit ([0-9a-f]+)$/
				if !c.commit.nil?
					all << c if is_match(c)
					c = Commit.new()
				end
				c.commit = $1
			elsif !c.commit.nil?
				if c.comment.nil?
					if line =~ /^([-\w]+):\s*(\S.*?)\s*$/
						key, value = $1.downcase, $2
						case key
							when "author"
								c.author = value
							when "repository"
								c.repos = value
							when "date"
								c.date = DateTime.parse(value)
						end
					elsif line =~ /\S/
						c.comment = StringIO.new()
					end
				end
				if !c.comment.nil?
					c.comment << line
				end
			end
		end
		all << c if is_match(c)
		CSV {|out|
			out << %w(Date Commit Repository Author Comment)
			all.each{|c| c.comment = c.comment.string.strip.gsub(/^\s+/,"") }
			all.sort {|a,b| a.to_a <=> b.to_a }.uniq.each {|c| out << c.to_a }
		}
	'
