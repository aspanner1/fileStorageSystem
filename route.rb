require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require 'pry'
require 'yaml'

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  authorized_check
  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

post "/:filename" do
  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

get "/views/new" do 
  authorized_check
  erb :new
end 

post "/new/create" do 
  authorized_check
  file_path = File.join(data_path, params[:filename])
  File.write(file_path, "")
  session[:message] = "#{params[:filename]} has been created"

  redirect "/"
end 

get "/:filename/delete" do 
  authorized_check
  file_path = File.join(data_path, params[:filename])
  File.delete(file_path)
  session[:message] = "#{params[:filename]} was deleted"
  
  redirect "/"

end 

get "/user/signin" do 
  erb :signin
end 

post "/user/auth" do 
  session[:username] = params[:username]
  session[:password] = params[:password]
  if name_and_password_match
    session[:message] = "Welcome!"
    redirect "/"
  else 
    session[:message] = "Invalid credentials"
    status 422
    erb :signin
  end 
end 

post "/user/signout" do 
  session.delete(:username)
  session.delete(:password)
  session[:message] = "You have been signed out"
  redirect "/"
end 

def authorized_check
  unless name_and_password_match
    session[:message] = "You must be signed in to do that"
    redirect "/"
  end 
end 

def name_and_password_match
  users = YAML.load_file('users.yml')
  match_hash = users.select do |username, password|
    session[:username] == username && password == session[:password]
  end 

  !match_hash.empty?
end 
