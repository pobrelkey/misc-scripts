#!/usr/bin/env ruby

#
#  A script for generating random passphrases in the style of
#  https://xkcd.com/936 ("correct horse battery staple").
#

require 'optparse'
require 'securerandom'
require 'set'


# 1296 words from the short variant of the EFF's Diceware lists:
#     https://www.eff.org/deeplinks/2016/07/new-wordlists-random-passphrases
# ...with words I judged problematic for various reasons (trade/proper names,
# possible non-words in English, homophones, words with uncertain spellings,
# words which might give fodder to an adversary looking to make trouble)
# replaced with short words from the longer variant of the list
WORDS = %w(
	acid acorn acre acts afar affix aged agent agile aging agony ahead
	aide aids aim ajar alarm alias alibi alien alike alive aloe aloft
	aloha alone amend amino ample amuse angel anger angle ankle apple
	april apron aqua area arena argue arise armed armor army aroma
	array ahoy art ashen ashes atlas atom attic audio avert avoid
	awake award awoke axis bacon badge bagel baggy baked baker balmy
	banjo barge barn bash basil bask batch bath baton bats blade
	blank blast blaze bleak blend bless blimp blink bloat blob blog
	blot blunt blurt blush boast boat body boil dork bolt boned boney
	bonus bony book booth boots boss botch both boxer breed bribe
	brick bride brim bring brink brisk broad broil broke brook broom
	brush buck bud buggy bulge bulk bully bunch bunny bunt bush bust
	busy buzz cable cache cadet cage cake calm cameo canal candy cane
	canon cape card cargo carol carry carve case cash cause cedar
	chain chair chant chaos charm chase cheek cheer chef chess chest
	chew chief chili chill chip chomp chop chow chuck chump chunk
	churn chute cider cinch city civic civil clad claim clamp clap
	clash clasp class claw clay clean clear cleat cleft clerk click
	cling clink clip cloak clock clone cloth cloud clump coach coast
	coat cod coil coke cola cold colt coma come comic comma cone cope
	copy coral cork cost cot couch cough cover cozy craft cramp crane
	crank crate crave crawl crazy creme crepe crept crib cried crisp
	crook crop cross crowd crown crumb crush crust cub cult cupid cure
	curl curry curse curve curvy cushy cut cycle dab dad daily dairy
	daisy dance dandy darn dart dash data date dawn deaf deal dean
	debit debt debug decaf decal decay deck decor decoy deed delay
	denim dense dent depth derby desk dial diary dice dig dill dime
	dimly diner dingy disco dish disk ditch ditzy dizzy dock dodge
	doing doll dome donor donut dose dot dove down dowry doze drab
	drama drank draw dress dried drift drill drive drone droop drove
	drown drum dry duck duct dude dug duke duo dusk dust duty dwarf
	dwell eagle early earth easel east eaten eats gab ebony irk
	echo edge eel eject elbow elder elf elk elm elope elude elves
	lard emit empty emu enter entry envoy equal erase error erupt
	essay etch evade even evict oaf evoke exact exit fable faced
	fact fade fall false fancy fang fax feast feed femur fence fend
	ferry fetal fetch fever fiber fifth fifty film filth final finch
	fit five flag flaky flame flap flask fled flick fling flint flip
	flirt float flock flop floss flyer foam foe fog foil folic folk
	food fool found fox foyer frail frame fray fresh fried frill frisk
	from front frost froth frown froze fruit gag gains gala game gap
	gas gave gear gecko geek gem genre gift gig gills given giver
	glad glass glide gloss glove glow glue goal going golf gong good
	gooey goofy gore gown grab grain grant grape graph grasp grass
	grave gravy gray green greet grew grid grief grill grip grit
	groom grope growl grub grunt guide gulf gulp gummy guru gush gut
	guy habit half halo halt happy harm hash hasty hatch hate haven
	hazel hazy heap heat heave hedge hefty help herbs hers hub hug
	hula hull human humid hump hung hunk hunt hurry hurt hush hut
	ice icing icon icy igloo image ion iron oink issue item ivory
	ivy jab jam jaws jazz jeep jelly jet jiffy job jog jolly jolt
	jot joy judge juice juicy july jumbo jump junky juror jury keep
	keg kept kick kilt king kite kitty kiwi knee knelt koala judo
	ladle lady lair lake lance land lapel large lash lasso last latch
	late lazy left legal lemon lend lens lent level lever lid life
	lift lilac lily limb limes line lint lion lip list lived liver
	lunar lunch lung lurch lure lurk lying lyric mace maker malt mama
	mango manor many map march mutt marry mash match mate math moan
	mocha moist mold mom moody mop morse most motor motto mount mouse
	mousy mouth move movie mower mud mug mulch mule mull myth mummy
	mural muse music musky mute nacho nag nail name nanny nap navy
	near neat neon nerd nest net next niece ninth nutty oak oasis
	oat ocean oil old olive omen onion only ooze opal open opera opt
	otter ouch ounce outer oval oven owl ozone pace pagan pager palm
	panda panic pants panty paper park party pasta patch path patio
	payer pecan penny pep perch perky perm pest petal petri petty
	photo plank plant plaza plead plot plow pluck plug plus poach
	pod poem poet pogo point poise poker polar polio polka polo pond
	pony poppy pork poser pouch pound pout power prank press print
	prior prism prize probe prong proof props prude prune pry pug
	pull pulp pulse puma punch punk pupil puppy purr purse push putt
	quack quake query quiet quill quilt quit quota quote rabid race
	rack radar radio raft rage raid rail rake rally ramp ranch range
	rank rant rash raven reach react ream rebel recap relax relay
	relic remix repay repel reply rerun reset rhyme rice rich ride
	rigid rigor rinse riot ripen rise risk ritzy rival river roast
	robe robin rock rogue roman romp rope rover royal ruby rug ruin
	rule runny rush rust rut sadly sage said saint salad salon salsa
	salt same sandy santa satin sauna saved savor sax say scale oops
	scan scare scarf scary scoff scold scoop scoot scope score scorn
	scout scowl scrap scrub scuba scuff sect sedan self send sepia
	serve set seven shack shade shady shaft shaky sham shape share
	sharp shed sheep sheet shelf shell shine shiny ship shirt shock
	shop shore shout shove shown showy shred shrug shun shush shut
	shy sift silk silly silo sip siren sixth size skate skew skid
	skier skies skip skirt skit sky slab slack slain slam slang slash
	slate slaw sled sleek sleep sleet slept slice slick slimy sling
	slip slit slob slot slug slum slurp slush small smash smell smile
	smirk smog snack snap snare snarl sneak sneer sniff snore snort
	snout snowy snub snuff speak speed spend spent spew pox spill
	spiny spoil spoke spoof spool spoon sport spot spout spray spree
	spur squad squat squid stack staff stage stain stall stamp stand
	stank stark start stash state stays steam steep stem step stew
	stick sting stir stock stole stomp stony stood stool stoop stop
	storm stout stove straw stray strut stuck stud stuff stump stung
	stunt suds sugar sulk surf sushi swab swan swarm sway swear sweat
	sweep swell swept swim swing swipe swirl swoop swore syrup tacky
	taco tag take tall talon tamer tank taper taps tarot tart task
	taste tasty taunt thank thaw theft theme thigh thing think thong
	thorn those throb thud thumb thump thus tiara tidal tidy tiger
	tile tilt tint tiny trace track trade train trait trap trash tray
	treat tree trek trend trial tribe trick trio trout truce truck
	rare trunk try tug tulip tummy turf tusk tutor tutu tux tweak
	tweet twice twine twins twirl twist uncle uncut undo unify union
	unit untie upon upper urban used user usher utter value vapor sly
	venue verse vest veto vice video view viral spud visa visor vixen
	vocal voice void volt voter vowel wad wafer wager wages wagon wake
	walk wand wasp watch water wavy wheat whiff whole whoop wick widen
	widow width wife twig wilt wimp wind wing wink wipe wired wiry
	wise wish wispy woof wolf womb wool woozy word work worry wound
	woven wrath wreck wrist wow zap yam yard year yeast yelp
	yield yodel yoga zen zit yummy zebra zero zesty zippy zone zoom
)

DIGITS_RX = /^(.+?)([aeios])/


# Random password selection engine - complicated, but has to be if:
# 1. we want all possible random passwords to be equally likely
#    (thereby containing the same amount of entropy)
# 2. we want to be able to say how many possible passwords there are
#    (i.e. how many bits of entropy does the password have)
# This becomes more complicated the more constraints/tweaks you add
# (prefixes, acrostics, digit manipulation, etc.)

class CorrectHorse

	def initialize(words=WORDS, 
			bit_count=nil, max_length=nil, word_count=nil,
			prefix=nil, prefix_frac=0.5, acrostic=nil,
			caps=false, digitify=false,
			joiner=' ')
		@bit_count = bit_count
		@max_length = max_length
		@word_count = word_count
		@prefix = prefix
		@prefix_frac = prefix_frac
		@acrostic = acrostic
		@caps = caps
		@digitify = digitify
		@joiner = joiner
		@words = words
		@min_word_length = words.collect{|x| x.length }.min

		@state_map = create_markov_tree()
		@count_cache = {}
		@possible_outcomes = outcome_count(@state_map,@count_cache)
		raise ArgumentError.new('no possible outcomes given specified options') if @possible_outcomes == 0
	end

private
	ROOT_STATE='*'

	def transition(next_word, old_state=ROOT_STATE)
		new_state = (old_state == ROOT_STATE) ?  {} : old_state.dup
		new_state[:count] = (new_state[:count] || 0) + 1 if !@word_count.nil? || !@prefix.nil? || !@bit_count.nil?
		return nil if !@word_count.nil? && new_state[:count] > @word_count
		return nil if !@acrostic.nil? && @acrostic[new_state[:count]-1] != next_word[0]
		if !@prefix.nil?
			return nil if old_state == ROOT_STATE && !next_word.start_with?(@prefix)
			new_state[:prefixed_count] = (new_state[:prefixed_count] || 0) + (next_word.start_with?(@prefix) ? 1 : 0)
		end
		new_state[:digitable] = new_state[:digitable] || (next_word =~ DIGITS_RX ? true : false) if @digitify
		if !@max_length.nil?
			new_state[:length] = old_state == ROOT_STATE ? next_word.length : (new_state[:length] + @joiner.length + next_word.length)
			return nil if new_state[:length] > @max_length
		end
		return new_state.freeze
	end

	def is_acceptable_end_state(state)
		return false if state == ROOT_STATE
		return false if !@word_count.nil? && state[:count] != @word_count
		return false if @digitify && !state[:digitable]
		return false if !@prefix.nil? && state[:prefixed_count] < state[:count] * @prefix_frac
		return false if !@max_length.nil? && state[:length] > @max_length
		return true
	end

	def has_further_states(state)
		return true if state == ROOT_STATE
		return false if !@max_length.nil? && state[:length] > @max_length - @joiner.length - @min_word_length
		return false if !@word_count.nil? && state[:count] == @word_count
		return true
	end

	def outcome_count(state_map, cache={}, from_state=ROOT_STATE)
		return cache[from_state] if cache.has_key?(from_state)
		transition_map = state_map[from_state]
		return cache[from_state] = (is_acceptable_end_state(from_state) ? 1 : 0) if transition_map.nil? || transition_map.empty?
		return cache[from_state] = transition_map.keys.inject(0){|a,b| a + transition_map[b] * outcome_count(state_map,cache,b) }
	end

	def create_markov_tree()
		# if @bit_count in use, build up a Markov tree one layer at a time until
		#    log_2(number of possible outcomes) >= @bit_count
		# otherwise construct a Markov tree to exhaustion of possible states
		state_map = {}
		new_states = nil
		while new_states.nil? || (!@bit_count.nil? ? (Math.log(outcome_count(state_map),2) < @bit_count) : !new_states.empty?)
			old_states = new_states || [ROOT_STATE]
			new_states = Set.new
		   	old_states.each do |old_state|
				transition_map = {}
				@words.each do |word|
					new_state = transition(word, old_state)
					next if new_state.nil?
					transition_map[new_state] = (transition_map[new_state] || 0) + 1
				end if has_further_states(old_state)
				new_states = new_states.union(transition_map.keys)
				state_map[old_state] = transition_map
			end
			new_states = new_states - old_states
		end
		return state_map.freeze
	end

public

	attr_reader :possible_outcomes

	def random_password()
		# use saved Markov chain stats to pick a password in such a way that all outcomes are equally likely
		result_words = []
		current_state = ROOT_STATE
		until is_acceptable_end_state(current_state)
			result_words = []
			current_state = ROOT_STATE
			bits = SecureRandom.rand(@possible_outcomes)
			until !@state_map.has_key?(current_state) || @state_map[current_state].empty?
				@words.each do |word|
					next_state = transition(word, current_state)
					next if next_state.nil?
					state_outcome_count = outcome_count(@state_map, @count_cache, next_state)
					if bits < state_outcome_count
						result_words << word
						current_state = next_state
						break
					else
						bits -= state_outcome_count
					end
				end
			end
		end
		result_words.collect!{|x| x.capitalize } if @caps
		if @digitify
			index_to_digitify = result_words.each_with_index.collect{|x,i| (x =~ DIGITS_RX) ? i : nil }.compact.max
			result_words[index_to_digitify] = result_words[index_to_digitify].sub(DIGITS_RX){ $1+$2.tr('aeios','43105') }
		end
		return result_words.join(@joiner)
	end

end



######## utility functions

def croak(msg)
	STDERR.print("ERROR: %s\n" % msg)
	exit(1)
end

# default number of bits of entropy for the password
DEFAULT_BITS = 48
DEFAULT_PREFIX_FRAC = 0.5


######## main ########

def main()
	bit_count = max_length = word_count = prefix = acrostic = nil
	caps = digitify = verbose = false
	repeat = 1
	prefix_frac = DEFAULT_PREFIX_FRAC
	joiner = ' '
	words = WORDS

	OptionParser.new do |opts|
		opts.banner = "Random passphrase generator in the style of https://xkcd.com/936/\nUsage: #{File.basename(__FILE__)} [options]"
		opts.on('-b', '--bits BITS', Float, "Bits of entropy in output (default: #{DEFAULT_BITS})") {|v| bit_count = v.to_f }
		opts.on('-l', '--length CHARS', Integer, 'result should be at most this many characters Long') {|v| max_length = v.to_i }
		opts.on('-w', '--words COUNT', Integer, 'result should be this many Words long') {|v| word_count = v.to_i }
		opts.on('-c', '--caps', 'Capitalize first letter of each word') { caps = true }
		opts.on('-d', '--digit', 'change one letter to a Digit') { digitify = true }
		opts.on('-y', '--hyphens', 'join words together with hYphens') { joiner = '-' }
		opts.on('-u', '--underscores', 'join words together with Underscores') { joiner = '_' }
		opts.on('-j', '--join JOINER', String, 'specify Joiner which should appear between words') {|v| joiner = v }
		opts.on('-m', '--camel', 'join words in caMel-case (implies -c -j \'\')') { caps = true; joiner = '' }
		opts.on('-s', '--start-with PREFIX', String, 'first word and some fraction of others should Start with PREFIX') {|v| prefix = v.strip.downcase }
		opts.on('-S', '--start-fraction FRACTION', Float, "what fraction of all words should start with prefix (default: #{DEFAULT_PREFIX_FRAC})") {|v| prefix_frac = v.to_f }
		opts.on('-a', '--acrostic WORD', String, 'result should be an Acrostic which spells WORD') {|v| acrostic = v.strip.downcase }
		opts.on('-r', '--repeat COUNT', Integer, 'print this many random passwords') {|v| repeat = v.to_i }
		opts.on('-f', '--word-file FILE', String, 'File containing words to be chosen randomly') do |v|
			words = File.read(v).scan(/(?:^|(?<=\s))([a-z]+)(?:$|(?=\s))/).flatten
		end
		opts.on('-v', '--verbose', 'Verbose output') { verbose = true }
	end.parse!

	# TODO move these into the class
	croak('you cannot specify both -b and either -l or -w') if !bit_count.nil? && (!max_length.nil? || !word_count.nil?)
	croak('you cannot specify both -a and -s') if !acrostic.nil? && !prefix.nil?
	croak('you cannot specify both -a and -b') if !acrostic.nil? && !bit_count.nil?
	croak('value for -a not consistent with value for -w') if !acrostic.nil? && !word_count.nil? && acrostic.length != word_count
	croak('you must specify a positive number for -b') if !bit_count.nil? && bit_count <= 0
	croak('you must specify a positive number for -l') if !max_length.nil? && max_length <= 0
	croak('you must specify a positive number for -w') if !word_count.nil? && word_count <= 0
	croak('you must specify a positive number for -r') if !repeat.nil? && repeat <= 0
	croak('you must specify a number between 0.0 and 1.0 for -S') if prefix_frac <= 0 || prefix_frac > 1.0
	word_count = acrostic.length if !acrostic.nil?
	bit_count = DEFAULT_BITS if bit_count.nil? && word_count.nil? && max_length.nil?

	shergar = CorrectHorse.new(words=words, 
			bit_count=bit_count, max_length=max_length, word_count=word_count,
			prefix=prefix, prefix_frac=prefix_frac, acrostic=acrostic,
			caps=caps, digitify=digitify,
			joiner=joiner)

	(1..repeat).each { puts(shergar.random_password()) }

	if verbose
		puts('# Output chosen from among %d possible outcomes (%.2f bits of entropy).' %
			[shergar.possible_outcomes, Math.log(shergar.possible_outcomes,2)])
		puts('# A choice from the above list can be regarded as having %.2f bits of entropy.' % 
			Math.log(shergar.possible_outcomes/repeat.to_f,2)) if repeat > 1
	end

end

main() if __FILE__ == $0

