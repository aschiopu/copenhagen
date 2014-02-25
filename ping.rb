require 'sinatra'
require 'mongo'
require 'digest/md5'
require 'json/ext'

configure do
  conn = Mongo::MongoClient.from_uri(ENV['DB_URI'])
  set :db, conn.db(ENV['DB_NAME'])

  set :views, Proc.new { File.join(root, "views") }
end

helpers do
  def grav(email)
    user_hash = Digest::MD5.hexdigest(email)
    "http://www.gravatar.com/avatar/#{user_hash}"
  end

  def update_player(email)
    player = settings.db['players'].find_one(email: email)
    match_wins = settings.db['matches'].find(player_won: email)
    match_lost = settings.db['matches'].find(player_lost: email)
    m_won = match_wins.count > 0 ? match_wins.count : 0
    m_lost = match_lost.count > 0 ? match_lost.count : 0
    g_wonA = match_wins.count > 0 ? match_wins.dup.map {|g| g['won']}.inject(:+) : 0
    g_wonB = match_lost.count > 0 ? match_lost.dup.map {|g| g['lost']}.inject(:+) : 0
    g_won = g_wonA + g_wonB
    g_lostA = match_wins.count > 0 ? match_wins.dup.map {|g| g['lost']}.inject(:+) : 0
    g_lostB = match_lost.count > 0 ? match_lost.dup.map {|g| g['won']}.inject(:+) : 0
    g_lost = g_lostA + g_lostB
    player['active']['matches_won'] = m_won
    player['active']['matches_lost'] = m_lost
    player['active']['games_won'] = g_won
    player['active']['games_lost'] = g_lost
    update = {
      active: player['active'],
    }
    player = settings.db['players'].update(
      {email: email},
      {'$set'=> update})
  end

  def opp_name(email)
    email.split('@')[0].capitalize
  end
end

get '/' do
  today = Time.now.utc
  @int_players = settings.db['players'].find(league: 'int')
    .sort({:'active.matches_won' => -1, :'active.games_won' => -1})
  @beg_players = settings.db['players'].find(league: 'beg')
    .sort({:'active.matches_won' => -1, :'active.games_won' => -1})
  @i_matches = settings.db['matches'].find(league: 'int',
    match_open: {'$lt' => today},
    match_close: {'$gt' => today})
  @b_matches = settings.db['matches'].find(league: 'beg',
    match_open: {'$lt' => today},
    match_close: {'$gt' => today})

  @w_o = today - (today.strftime('%w').to_i - 1)*24*60*60
  @string = "#{@w_o.strftime('%b')} #{@w_o.strftime('%d')} - #{@w_o.strftime('%d').to_i + 6}, #{@w_o.strftime('%Y')}"


  erb :landing
end

not_found do
  "Piss Off <br><a href='/'>Home</a>"
end

get '/update/:week' do
  week_zero = Time.new(2014,2,10)
  cur_week = params[:week].to_i
  this_week = (week_zero + 24*7*60*60*cur_week).utc
  @matches = settings.db['matches'].find(
    match_open: {'$lt' => this_week},
    match_close: {'$gt' => this_week}).to_a
  erb :update
end

post '/update' do
  id = params[:id]
  winner_email = params[:winner]
  won = params[:won].to_i
  lost = params[:lost].to_i

  match = settings.db['matches'].find_one(_id: BSON::ObjectId(id))
  match['participants'].delete(winner_email)
  loser_email = match['participants'].first

  results = {
    player_won: winner_email,
    player_lost: loser_email,
    won: won,
    lost: lost
  }

  # update match
  match = settings.db['matches'].update(
    {_id: BSON::ObjectId(id)},
    {'$set' => results})


  # update both players
  update_player(winner_email)
  update_player(loser_email)

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


  one_week = 7*24*60*60
  start_date = Time.new(2014,2,9)
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

  redirect '/'
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