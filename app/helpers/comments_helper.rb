module CommentsHelper
	def nested_comments(messages)
		messages.map do |message, sub_messages|
			render(message) + content_tag(:div, nested_comments(sub_messages), :class => "replies")
		end.join.html_safe
	end
end
