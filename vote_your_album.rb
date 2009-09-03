%w[rubygems sinatra json haml librmpd dm-core dm-aggregates].each { |lib| require lib }
%w[models/album models/song models/nomination models/vote].each { |model| require model }
require 'lib/mpd_proxy'

require 'lib/config'

# -----------------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------------
def execute_on_nomination(id, &block)
  nomination = Nomination.get(id.to_i)
  yield(nomination) if nomination
  render_upcoming
end

def json_status
  current = Nomination.current
  
  status = { :playing => MpdProxy.playing?, :volume => MpdProxy.volume }
  status = status.merge(:current_album => current.album.to_s, :current_song => MpdProxy.current_song,
    :time => MpdProxy.time, :down_votes_necessary => current.down_votes_necessary,
    :rateable => current.can_be_rated_by?(request.ip), :forceable => current.can_be_forced_by?(request.ip)
  ) if MpdProxy.playing?
  status.to_json
end

def render_upcoming
  @nominations = Nomination.active
  haml :_upcoming, :layout => false
end

helpers do
  def score_class(score); score > 0 ? "positive" : (score < 0 ? "negative" : "") end
end


# -----------------------------------------------------------------------------------
# Actions
# -----------------------------------------------------------------------------------
get "/" do
  haml :index
end
get "/embed" do
  haml :index, :layout => :embed
end
get "/list/:type" do |list_type|
  Album.send(list_type).map { |a| a.to_hash Album.value_method_for(list_type) }.to_json
end
get "/search" do
  Album.search(params[:q]).map { |a| a.to_hash }.to_json
end
get "/upcoming" do
  render_upcoming
end
get "/songs/:album" do |album_id|
  album = Album.get(album_id.to_i)
  @songs = (album ? album.songs : [])
  haml :_songs, :layout => false
end

get "/status" do
  json_status
end

post "/add/:id" do |album_id|
  album = Album.get(album_id.to_i)
  album.nominate(request.ip) if album
  render_upcoming
end
post "/up/:id" do |nomination_id|
  execute_on_nomination(nomination_id) { |nomination| nomination.vote 1, request.ip }
end
post "/down/:id" do |nomination_id|
  execute_on_nomination(nomination_id) { |nomination| nomination.vote -1, request.ip }
end
post "/remove/:id" do |nomination_id|
  execute_on_nomination(nomination_id) { |nomination| nomination.remove request.ip }
end
post "/force" do
  Nomination.current.force request.ip
  json_status
end
post "/rate/:value" do |value|
  Nomination.current.rate value.to_i, request.ip
  json_status
end

post "/control/:action" do |action|
  MpdProxy.execute action.to_sym
  json_status
end
post "/volume/:value" do |value|
  MpdProxy.change_volume_to value.to_i
end
post "/play" do
  MpdProxy.play_next unless MpdProxy.playing?
  json_status
end