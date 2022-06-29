#!/usr/bin/env bash

#
#  Git Historian
#
#  Go through any git repositories under the current directory
#  (or other directories as specified by the arguments),
#  dump out a CSV of "interesting" commits.
#

usage() {
	echo
	echo "HISTORIAN: Generate a CSV summary of Git commits across repositories"
	echo
	echo "Usage: historian.sh [options] [places to search for Git repositories]"
	echo
	echo "Options:"
	echo "    -a REGEX     Only list commits with author matching REGEX"
	echo "    -m REGEX     Only list commits with commit message matching REGEX"
	echo "    -r REGEX     Only list commits with repository URL matching REGEX"
	echo "    -s DATETIME  Only list commits since given DATETIME"
	echo "    -u DATETIME  Only list commits until given DATETIME"
	echo "    -o PATH      Write output to PATH (default: writes to stdout)"
	echo "    -d FORMAT    Use FORMAT for commit date output (default: %Y-%m-%d)"
	echo "    -h           Display this help message"
	echo
}

OUTPUT_PATH=/dev/stdout
REPOS_REGEXP="${REPOS_REGEXP:-.}"
DATE_FORMAT="${DATE_FORMAT:-%Y-%m-%d}"
while getopts "a:d:hm:o:r:s:u:" opt; do
	case ${opt} in
		h)
			usage
			exit 0
			;;
		a)
			AUTHOR_REGEXP="${OPTARG}"
			;;
		m)
			MESSAGE_REGEXP="${OPTARG}"
			;;
		r)
			REPOS_REGEXP="${OPTARG}"
			;;
		s)
			DATE_MIN="${OPTARG}"
			;;
		u)
			DATE_MAX="${OPTARG}"
			;;
		o)
			OUTPUT_PATH="${OPTARG}"
			;;
		\?)
			echo "ERROR: invalid Option: -$OPTARG" 1>&2
			exit 1
			;;
		:)
			echo "ERROR: invalid Option: -$OPTARG requires an argument" 1>&2
			exit 1
			;;
	esac
done
shift $((OPTIND -1))
export OPT_AUTHOR_REGEXP="${AUTHOR_REGEXP}"
export OPT_MESSAGE_REGEXP="${MESSAGE_REGEXP}"
export OPT_DATE_MIN="${DATE_MIN}"
export OPT_DATE_MAX="${DATE_MAX}"
export OPT_DATE_FORMAT="${DATE_FORMAT}"

find "${@:-.}" -name .git \
	| (
		while 
			read GITDIR && [ -n "${GITDIR}" ]
		do
			REPODIR="$(dirname "${GITDIR}")"
			pushd "${REPODIR}" >/dev/null
			GITURL="$(git remote get-url origin 2>/dev/null | grep -P -e "${REPOS_REGEXP}")"
			if [ -n "${GITURL}" ]
			then
				echo "$(echo -n "${GITURL}" | perl -e 'print unpack("H*",<>)')|$(echo -n "${REPODIR}" | perl -e 'print unpack("H*",<>)')"
			fi
			popd >/dev/null
		done
	) \
	| parallel --will-cite -I{} --line-buffer --colsep '\|' \
		bash -c \''cd "$(perl -e "print pack(\"H*\",\"{2}\")")" && git log | ruby -e '\''\'\'''\''
			require "csv"
			require "stringio"
			require "date"

			Commit = Struct.new(:date,:commit,:repos,:repos_basename,:author,:message)

			REPOS = ["{1}"].pack("H*")
			REPOS_BASENAME = REPOS.sub(/^.+\//,"").sub(/\.git$/,"")

			DATE_FORMAT = ENV["OPT_DATE_FORMAT"] =~ /\S/ ? ENV["OPT_DATE_FORMAT"] : "%Y-%m-%d"

			AUTHOR_REGEXP  = ENV["OPT_AUTHOR_REGEXP"] =~ /\S/ ? Regexp.compile(ENV["OPT_AUTHOR_REGEXP"]) : nil
			MESSAGE_REGEXP = ENV["OPT_MESSAGE_REGEXP"] =~ /\S/ ? Regexp.compile(ENV["OPT_MESSAGE_REGEXP"]) : nil
			DATE_MIN       = ENV["OPT_DATE_MIN"] =~ /\S/ ? DateTime.parse(ENV["OPT_DATE_MIN"]) : nil
			DATE_MAX       = ENV["OPT_DATE_MAX"] =~ /\S/ ? DateTime.parse(ENV["OPT_DATE_MAX"]) : nil

			def is_match(commit)
				return (
					(AUTHOR_REGEXP.nil? || (!commit.author.nil? && commit.author =~ AUTHOR_REGEXP)) &&
					(MESSAGE_REGEXP.nil? || (!commit.message.nil? && commit.message.string =~ MESSAGE_REGEXP)) &&
					(DATE_MIN.nil? || (!commit.date.nil? && commit.date >= DATE_MIN)) &&
					(DATE_MAX.nil? || (!commit.date.nil? && commit.date <= DATE_MAX))
				)
			end
			
			def dump(c)
				return if !is_match(c)
				c.date = c.date.strftime(DATE_FORMAT) if !c.date.nil?
				c.message = c.message.string.gsub(/^\s+/,"").gsub(/[\s\r\n]+/," ").strip if !c.message.nil?
				c.repos = REPOS
				c.repos_basename = REPOS_BASENAME
				puts c.to_a.to_csv
			end

			c = Commit.new()
			STDIN.each_line do |line|
				if line =~ /^commit ([0-9a-f]+)$/
					if !c.commit.nil?
						dump(c)
						c = Commit.new()
					end
					c.commit = $1
				elsif !c.commit.nil?
					if c.message.nil?
						if line =~ /^([-\w]+):\s*(\S.*?)\s*$/
							key, value = $1.downcase, $2
							case key
								when "author"
									c.author = value
								when "date"
									c.date = DateTime.parse(value)
							end
						elsif line =~ /\S/
							c.message = StringIO.new()
						end
					end
					if !c.message.nil?
						c.message << line
					end
				end
			end
			dump(c)
		'\''\'\'''\'\' \
	| ( echo 'Date,Commit,Repos,ReposBasename,Author,Message' ; sort | uniq ) >"${OUTPUT_PATH}"
