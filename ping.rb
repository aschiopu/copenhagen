require 'sinatra'
require 'mongo'
require 'digest/md5'

configure do
  uri = 'mongodb://admin:sjhvZFagAd1wMF8eB@widmore.mongohq.com:10010/pingpong'
  conn = Mongo::MongoClient.from_uri(uri)
  set :db, conn.db('pingpong')
  set :views, File.dirname(__FILE__) + "/views"
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
  erb :index
end

get '/player/:email' do
  email = params[:email]
  @user = settings.db['players'].find_one(email: email)
  @user_avatar = grav(email)
  erb :player
end

get '/schedule' do
  db = settings.db
  int_users = settings.db['players'].find(league: 'int')
  int_count = int_users.count


  int_users.each do |u|
    random = [*0..int_count-1].sample
    rand_chal = db['players'].find(league: 'int').limit(1).skip(random.to_i).next()


    myself = rand_chal['email'] == u['email']
    existing = db['matches'].find(players: {'$elemMatch' => {email: u['email']}}).count

    if !myself && existing == 0
      new_schedule = {
        players: [{email: u['email']},{email: rand_chal['email']}],
      }
      db['matches'].insert(new_schedule)
      puts 'will insert new entry'
      # insert new entry
    end
  end



  "asdasdas"
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