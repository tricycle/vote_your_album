%w[rubygems sinatra rest_client json haml librmpd dm-core dm-aggregates rio].each { |lib| require lib }
%w[album song nomination vote user update tag similarity starred_album].each do |model|
  require File.join(File.dirname(__FILE__), "models", model)
end
%w[mpd_proxy last_fm album_art last_fm_meta library].each do |lib|
  require File.join(File.dirname(__FILE__), "lib", lib)
end

require File.join(File.dirname(__FILE__), "config")

# -----------------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------------
def execute_on_nomination(id, do_render = true, &block)
  return "" unless logged_in?

  nomination = Nomination.get(id.to_i)
  yield(nomination) if nomination
  do_render ? render_upcoming : ""
end

def json_status
  current = Nomination.current

  status = { :playing => MpdProxy.playing?, :volume => MpdProxy.volume }
  status = status.merge(
    :id => current.id,
    :current_album => current.album.to_s,
    :current_song => MpdProxy.current_song,
    :current_art => current.art,
    :total => to_time(MpdProxy.total, false),
    :time => to_time(MpdProxy.time),
    :nominated_by => current.nominated_by,
    :voteable => current.can_be_voted_for_by?(current_user),
    :score => current.score_s,
    :score_class => current.score_class
  ) if MpdProxy.playing?
  status.to_json
end

def render_upcoming
  @nominations = Nomination.active
  haml :upcoming, :layout => false
end

def authenticate(token)
  response = JSON.parse(
    RestClient.post("https://rpxnow.com/api/v2/auth_info",
      :token => token,
      :apiKey => "15d9dea0e625eb09642bd796816ece60737521d7",
      :format => "json",
      :extended => "true"
    )
  )

  if response["stat"] == "ok"
    session["vya.user"] = response["profile"]["identifier"]
    User.create_from_profile(response["profile"]) unless current_user

    return true
  end

  return false
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def album_attributes(nomination, user)
    attr = { :ref => nomination.id }

    classes = ["album"]
    classes << "deleteable" if nomination.owned_by?(user)
    classes << nomination.score_class
    attr.update :class => classes.join(" ")

    if nomination.ttl
      attr.update(:title => "TTL: #{to_time(nomination.ttl)}")
    else
      attr.update(:title => "Click to show log")
    end

    attr
  end

  def to_time(seconds, remaining = true)
    time = []
    time << "%02d" % (seconds / 3600) if seconds >= 3600
    time << "%02d" % ((seconds % 3600) / 60)
    time << "%02d" % (seconds % 60)

    (remaining ? "-" : "") + time.join(":")
  end

  def logged_in?
    !!current_user
  end

  def current_user
    User.first :identifier => session["vya.user"]
  end
end


# -----------------------------------------------------------------------------------
# Actions
# -----------------------------------------------------------------------------------
get "/" do
  haml(logged_in? ? :index : :sign_in)
end

get "/music/:type" do |list_type|
  if list_type == "starred"
    list = current_user.favourite_albums
  else
    list = Album.send(list_type)
  end

  list.map { |a| a.to_hash(current_user) }.to_json
end

get "/search" do
  if params[:q] == "shuffle"
    res = Album.random
  elsif params[:q] =~ /^artist:(.*)$/
    res = Album.all(:artist.like => "#{$1}%")
  elsif params[:q] =~ /^tag:(.*)$/
    res = Tag.first(:name => $1).albums
  else
    res = Album.search(params[:q])
  end

  res.map { |a| a.to_hash(current_user) }.to_json
end

get "/upcoming" do
  render_upcoming
end

get "/status" do
  json_status
end

get "/updates" do
  @updates = Update.all
  haml :updates, :layout => false
end

get "/songs/:id" do |album_id|
  album = Album.get(album_id.to_i)

  res = (album ? album.songs : []).map { |s| s.to_hash }
  res.each { |s| s[:length] = to_time(s[:length], false) }
  res.to_json
end

post "/add" do
  render "" unless logged_in?

  album = Album.get(params[:album_id].to_i)
  album.nominate(current_user, params[:songs]) if album

  MpdProxy.play_next unless MpdProxy.playing?

  render_upcoming
end

post "/up/:id" do |nomination_id|
  execute_on_nomination(nomination_id) { |nomination| nomination.vote 1, current_user }
end

post "/down/:id" do |nomination_id|
  execute_on_nomination(nomination_id) { |nomination| nomination.vote -1, current_user }
end

post "/remove/:id" do |nomination_id|
  execute_on_nomination(nomination_id) { |nomination| nomination.remove current_user }
end

post "/star/:id" do |album_id|
  current_user.toggle_favourite Album.get(album_id.to_i)
  ""
end

post "/control/:action" do |action|
  MpdProxy.execute action.to_sym
  json_status
end

post "/volume/:value" do |value|
  MpdProxy.change_volume_to value.to_i
end

post "/library/update" do
  Library.update
end

get "/sign-in" do
  haml :sign_in
end

post "/signed-in" do
  if authenticate(params[:token])
    redirect "/"
  else
    redirect "/sign-in"
  end
end
