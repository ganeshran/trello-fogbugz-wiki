require 'trello'
require 'open-uri'
require 'htmlentities'
require 'uri'
require 'net/http'
require 'net/smtp'
require 'fogbugz'
require 'json'

=begin
Author : Ganesh Ranganathan
Description: The script copies all the information on a Trello Board to a
fogbugz wiki page. It can be set as a cron job to copy the latest state of 
your trello board and avoid having to duplicate the information
to your organization's fogbugz wiki 
=end

module Constants

	module Fogbugz
		URI = '<Fogbugz_URL>' #The URI Endpoint of your fogbugz deployment
		API_URL = '<FOGBUGZ_API_URL>' #The API url of your fogbugz deployment. Usually ends with api.asp
		FOGBUGZ_TOKEN = "<Enter API Token" #The API Token
		WIKI_ARTICLE_ID = 0 #Wiki Article ID where the information has to be copied.WARNING: Existing info will be deleted
		WIKI_PAGE_TITLE = 'Sample Trello Board Title' #Title of the Wiki page
	end 

	module Trello
		#Fill Trello OAuth Key, AppSecret and token and the board ID
		TRELLO_OAUTH_KEY = '<OAUTH_KEY>' 
		TRELLO_OAUTH_APPSECRET = 'OAUTH_APP_SECRET'
		#only use a read only token for this script. Since we dont want to delete data even by mistake
		TRELLO_OAUTH_APPTOKEN = 'APP_TOKEN'
		TRELLO_BOARD_ID = 'BOARD_ID'
	end

	module Email
		#Email Details to notify user via Email
		SMTP_SERVER = 'Enter SMTP Server'
		FROM_EMAIL_ADDRESS = 'From Email Address'
	end
end 

module TrelloModule

 class Board

 	attr_accessor :title 
 	attr_accessor :members
 	attr_accessor :lists

 	def initialize(trello_board) 		
 		#initialize Arrays
 		@members = Array.new
 		@lists = Array.new 
 		#populate members 
 		@title = trello_board.name
 		trello_board.members.each{ |member| @members.push(User.new(member)) }
  		trello_board.lists.each{ |list|  @lists.push(List.new(list)) }
 	end
 end

 class List
 	attr_accessor :cards
 	attr_accessor :name

 	def initialize(trello_list)
 		#initialize Arrays
 		@cards = Array.new
 		#populate basic variable
 		@name = trello_list.name
 		#Populate Cards Array
 		trello_list.cards.each{ |card| @cards.push(Card.new(card)) }
 	end
 end

 class Card
 	attr_accessor :comments
 	attr_accessor :name 
 	attr_accessor :description
 	attr_accessor :members

 	def initialize(trello_card)
 		#Initialize Arrays
 		@comments = Array.new 
 		@members = Array.new

 		@name = trello_card.name
 		@description = trello_card.description

 		if trello_card.members.count > 0 
 		#populate Users
 			trello_card.members.each{ |member|
 			@members.push(User.new(member))
 		}
 		end
 		
 		#populate Comments
 		trello_card.actions.select{ |action|
 			action.type == "commentCard"
 			}.reverse.each {|comment|
 				@comments.push(Comment.new(comment))
 			}
 	end
 end

 class User
 	attr_accessor :full_name

 	def initialize(trello_member)
 		@full_name  = trello_member.full_name
 	end

 end

 class Comment
 	attr_accessor :text
 	attr_accessor :creator

 	def initialize(trello_comment)
 		@text = trello_comment.data["text"]
 		@creator = User.new(Helper.get_trello_member(trello_comment.member_creator_id))
 	end

 end

 class Helper

 	def self.get_trello_member(member_id)
 		Trello::Member.find(member_id)
 	end

 	#this method generates the output html
 	def self.get_output_html(board)
 		body_html = "<h2>Members</h2>"
 		board.members.each{ |member| body_html << member.full_name << "<br />" }
 		body_html << "<br /><h2>Lists</h2>"
		board.lists.each { |list| body_html << list.name << "<br />" }
		body_html << "<br /><h2>Cards</h2>"
		board.lists.each { |list| 
							  list.cards.each {|card| 
									body_html << "<h3>" << HTMLEntities.new.encode(card.name) << "</h3>" 
									body_html << "Description: " << HTMLEntities.new.encode(card.description).gsub(/\n/, '<br />') 
 		 							body_html << "<br />Assigned To:"
 		 							card.members.each { |member| body_html << member.full_name << ", "  }
 		 							body_html << "<br />Comments:<br /><ul>"
 		 							card.comments.each { |comment|
 		 								body_html << "<li><span style=""font-size:14px; line-height:14px""><b>" << comment.creator.full_name << "</b>: " << HTMLEntities.new.encode(comment.text) << "</span></li>"
 		 							}
 		 							body_html << "</ul><hr />"
 		 						}
 		 					}
 		
 		body_html
 	end

 	def self.write_to_fogbugz(body_html)

 		#The fogbugz-ruby gem doesnt work for larg wiki pages because it tries to send the Body in the URL and fails when the size limit is breached
=begin
		fogbugz = Fogbugz::Interface.new(:token => Constants::FOGBUGZ_TOKEN, :uri => Constants::URI )
		response = fogbugz.command(:editArticle, :sBody => body_html, :ixWikipage => Constants::WIKI_ARTICLE_ID, :sHeadLine => Constants::WIKI_PAGE_TITLE)
		puts response
=end
		uri = URI.parse("#{Constants::Fogbugz::API_URL}?cmd=editArticle&token=#{Constants::Fogbugz::FOGBUGZ_TOKEN}&ixWikipage=#{Constants::Fogbugz::WIKI_ARTICLE_ID}&sHeadLine=#{URI::encode(Constants::Fogbugz::WIKI_PAGE_TITLE)}")
		http = Net::HTTP.new(uri.host)
		http.use_ssl = false
		http.verify_mode = OpenSSL::SSL::VERIFY_NONE
		request = Net::HTTP::Post.new("#{uri.path}?#{uri.query}")
		body = {'sBody' => body_html}
		request.set_form_data(body,';');
		response = http.request(request) 
		puts response.body
 	end

 	def self.send_email(output, recipient)
 		message = <<MESSAGE_END
From: Trello Admin <#{Constants::Email::FROM_EMAIL_SERVER}>
To: A Test User <#{recipient}>
MIME-Version: 1.0
Content-type: text/html
Subject: #{Constants::Fogbugz::WIKI_PAGE_TITLE} backup 
#{output}
MESSAGE_END

Net::SMTP.start(Constants::Email::SMTP_SERVER) do |smtp|
  smtp.send_message message,Constants::Email::FROM_EMAIL_ADDRESS, recipient
  end
 	end
 end

class Main

	def initialize
		init_trello_api
		board =  Board.new(Trello::Board.find(Constants::Trello::TRELLO_BOARD_ID))
		output = Helper.get_output_html(board)
		Helper.write_to_fogbugz(output)
	end

	private 
	def init_trello_api
		Trello::Authorization.const_set :AuthPolicy, Trello::Authorization::OAuthPolicy
		Trello::Authorization::OAuthPolicy.consumer_credential = Trello::Authorization::OAuthCredential.new  Constants::Trello::TRELLO_OAUTH_KEY, Constants::Trello::TRELLO_OAUTH_APPSECRET
		Trello::Authorization::OAuthPolicy.token = Trello::Authorization::OAuthCredential.new Constants::Trello::TRELLO_OAUTH_APPTOKEN , nil
	end
end
end

TrelloModule::Main.new

