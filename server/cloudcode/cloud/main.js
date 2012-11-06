
// Use Parse.Cloud.define to define as many cloud functions as you want.
// For example:
Parse.Cloud.define("hello", function(request, response) {
  response.success("Hello world!");
});

Parse.Cloud.define("latestDate", function(request, cloudResponse) {
	Parse.Cloud.httpRequest({
  		url: 'http://api.tumblr.com/v2/blog/lesjoiesducode.tumblr.com/info',
  		params: {
    			api_key : '2oiq2RJVxKq2Pk2jaHoyLvOwiknYNKiuBwaZIXljQhSyMHsmMb'
  		},
  		success: function(httpResponse) {
			var tumblrResponse = JSON.parse(httpResponse.text);
			var postCount = tumblrResponse.response.blog.posts;
			
			var query = new Parse.Query(Parse.Installation);
			query.lessThan("postCount", postCount);
			
			Parse.Push.send({
				where: query,
				data: {
					alert: "push alert"
				}
			}, {
				success: function() {
					cloudResponse.success("Push happened");
				},
				error: function(error) {
					cloudResponse.error("Error happened");
				}
			});
  		}
	});
});

Parse.Cloud.define("other", function(request, response) {
	var query = new Parse.Query(Parse.Installation);
	var date = new Date();
	query.lessThan("lastPostDate", date);

	Parse.Push.send({
		where: query,
		data: {
			alert: "push alert"
		}
	}, {
		success: function() {
			response.success("Push happened");
		},
		error: function(error) {
			response.error("Error happened");
		}
	});
});

