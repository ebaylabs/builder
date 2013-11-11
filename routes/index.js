
/*
 * GET home page.
 */

exports.index = function(req, res){
  res.render('index', { title: 'BuildrO - build bot for openstratus components' });
};