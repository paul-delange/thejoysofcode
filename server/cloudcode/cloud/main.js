
Parse.Cloud.define("sendPush", function(request, cloudResponse) {

	var url;
	var msg;

	if( request.params.language === "fr" ) {
		url = "http://api.tumblr.com/v2/blog/lesjoiesducode.tumblr.com/info";
		msg = "Nouvelles images disponibles";
  	}
	else if( request.params.language === "en" ) {
		url = "http://api.tumblr.com/v2/blog/thejoysofcode.tumblr.com/info";
		msg = "New videos available";
	}
	else {
		cloudResponse.error("Bad language parameter: " + request.params.language);
	}

	Parse.Cloud.httpRequest({
  		url: url,
  		params: {
    			api_key : '2oiq2RJVxKq2Pk2jaHoyLvOwiknYNKiuBwaZIXljQhSyMHsmMb'
  		},
  		success: function(httpResponse) {
			var tumblrResponse = JSON.parse(httpResponse.text);
			var postCount = tumblrResponse.response.blog.posts;
			
			var query = new Parse.Query(Parse.Installation);
			query.lessThan("postCount", postCount);
            		query.equalTo("language", request.params.language);
                       
			Parse.Push.send({
				where: query,
				data: {
					alert: "new videos"
				}
			}, {
				success: function() {
					cloudResponse.success("Push happened");
				},
				error: function(error) {
					cloudResponse.error("Error happened");
				}
			});
  		},
	       error: function(httpResponse) {
			cloudResponse.error("Tumblr error with: " + url);
		}
	});

});