require 'sinatra'
require 'mongo'
require 'digest/md5'
require 'json/ext'

configure do
  uri = 'mongodb://admin:sjhvZFagAd1wMF8eB@widmore.mongohq.com:10010/pingpong'
  conn = Mongo::MongoClient.from_uri(uri)
  set :db, conn.db('pingpong')
  set :views, File.dirname(__FILE__) + "/views"
  enable :method_override
end

helpers do
  def grav(email)
    user_hash = Digest::MD5.hexdigest(email)
    "http://www.gravatar.com/avatar/#{user_hash}"
  end
end


get '/' do
  @players = settings.db['players'].find()
  @int_players = settings.db['players'].find(league: 'int')
  @beg_players = settings.db['players'].find(league: 'beg')
  today = Time.now.utc
  @i_matches = settings.db['matches'].find(league: 'int',
    match_open: {'$lt' => today},
    match_close: {'$gt' => today})
  @b_matches = settings.db['matches'].find(league: 'beg',
    match_open: {'$lt' => today},
    match_close: {'$gt' => today})

  erb :index
end

get '/update' do
  today = Time.now.utc
  @matches = settings.db['matches'].find(
    match_open: {'$lt' => today},
    match_close: {'$gt' => today}).to_a
  erb :update
end

post '/update' do
  puts "WOOO GOT HERE #{params}"
  puts "WOOO GOT HERE #{params}"
  puts "WOOO GOT HERE #{params}"

  id = params[:id]
  winner_email = params[:winner]
  won = params[:won].to_i
  lost = params[:lost].to_i

  results = {
    winner: winner_email,
    won: won,
    lost: lost
  }

  # update match
  match = settings.db['matches'].update(
    {_id: BSON::ObjectId(id)},
    {'$set' => results})

  # update winner

  winner = settings.db['players'].find_one(email: winner_email)
  puts 'HERE IS WHAT I FOUND'

  winner['active']['matches_won'] += 1
  winner['active']['games_won'] += 3
  winner['active']['games_lost'] += lost
  winner['all_time']['matches_won'] += 1
  winner['all_time']['games_won'] += 3
  winner['all_time']['games_lost'] += lost

  update = {
    active: winner['active'],
    all_time: winner['all_time']
  }

  winner = settings.db['players'].update(
    {email: winner_email},
    {'$set' => update})


  # update loser


  redirect '/'
end


get '/player/:email' do
  email = params[:email]
  @user = settings.db['players'].find_one(email: email)
  @user_avatar = grav(email)
  erb :player
end

get '/newschedule' do
  erb :nschedule
end

get '/nextschedule' do
  puts 'got HERE'

  puts "THIS IS THE PARAMS #{params}"

  today = Time.now.utc
  w = params[:week].to_i
  one_week = 7*24*60*60
  b_matches = settings.db['matches'].find(league: 'beg',
    match_open: {'$lt' => today + one_week*w},
    match_close: {'$gt' => today + one_week*w}).to_a
  i_matches = settings.db['matches'].find(league: 'int',
    match_open: {'$lt' => today + one_week*w},
    match_close: {'$gt' => today + one_week*w}).to_a
  {beg: b_matches, int: i_matches}.to_json
end

post '/newschedule' do
  db = settings.db
  league =  params[:league] || 'int'
  db['matches'].remove(leage: league)
  one_week = 7*24*60*60
  start_date = Time.new(2014,2,2)
  players = db['players'].find(league: league).to_a
  p_count = players.count + 1
  p_count_mod = p_count - 1
  matches_per_week = (p_count/2.to_f).ceil
  n_weeks = p_count - 1


  for w in 0...n_weeks
    date_open = start_date + one_week*w
    date_close = date_open + one_week

    for m in 0...matches_per_week
      if w == 0
        players[p_count_mod] = players[1]
        if m == 0
          playerA = players[0]
          playerB = players[p_count_mod-w]
        else
          playerA = players[m]
          playerB = players[p_count_mod-m]
        end
      else
        seventh = 7 - w*2 + 1
        while seventh < 0
          seventh += 7
        end
        seventh = seventh == p_count_mod ? 0 : seventh
        players[p_count_mod] = players[seventh]
        if m == 0
          playerA = players[0]
          playerB = players[p_count_mod-1*w]
        elsif m < w
          aIndex = p_count_mod - (w-m)
          bIndex =  aIndex - m*2
          if w+m >= p_count_mod
            bIndex -= 1
          end
          playerA = players[aIndex]
          playerB = players[bIndex]
        elsif m == w
          playerA = players[p_count_mod]
          playerB = players[p_count_mod-2*w]
        else
          playerA = players[m - w]
          playerB = players[p_count_mod-m-w]
        end

      end
      match = {
        participants: [playerA['email'],playerB['email']],
        league: league,
        match_open: date_open.utc,
        match_close: date_close.utc
      }
      db['matches'].insert(match)
    end
  end

  redirect '/schedule'
end

get '/schedule' do
  today = Time.now.utc
  @i_matches = settings.db['matches'].find(league: 'int',
    match_open: {'$lt' => today},
    match_close: {'$gt' => today})
  @b_matches = settings.db['matches'].find(league: 'beg',
    match_open: {'$lt' => today},
    match_close: {'$gt' => today})

  erb :schedule
end

get '/newplayer' do
  erb :newplayer
end

post '/newplayer' do
  db = settings.db

  user = {
    first_name: params['first_name'],
    last_name: params['last_name'],
    email: params['email'],
    league: params['league'],
    active: {
      matches_won: 0,
      matches_lost: 0,
      games_won: 0,
      games_lost: 0,
    },
    all_time: {
      matches_won: 0,
      matches_lost: 0,
      games_won: 0,
      games_lost: 0,
    }
  }

  db['players'].insert(user)
  "<a href='/'>Back</a>"
end