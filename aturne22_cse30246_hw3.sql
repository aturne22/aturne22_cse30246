/* 1. 05pts How many total spectators have seen a game in this dataset? */
SELECT SUM(attendance) total_attendance FROM cfb_game_stats;

/* 2. 05pts On what down do most penalties occur? */
SELECT down FROM cfb_play WHERE play_type = 'PENALTY' GROUP BY down ORDER BY COUNT(*) desc LIMIT 1;

/* 3. 10pts The Red zone is when the ball is within the 20 yards of the goal line. A red zone attempt is when the team moves inside the red zone, and a successful red zone attempt is when the team scores a touchdown. Which 5 teams with over 10 red zone attempts have the best red zone success rate (%) and what was their success rate? */
SELECT success.name, success.count / overall.count AS rate FROM
(SELECT team.name as name, COUNT(*) as count FROM
(SELECT DISTINCT team_id, name, conference_id FROM cfb_team) as team LEFT JOIN
cfb_drive ON cfb_drive.team_id = team.team_id WHERE cfb_drive.red_zone_attempt = 1 AND cfb_drive.end_reason = 'TOUCHDOWN' GROUP BY team.name) AS success join
(SELECT team.name as name, COUNT(*) as count FROM
(SELECT DISTINCT team_id, name, conference_id FROM cfb_team) as team LEFT JOIN
cfb_drive ON cfb_drive.team_id = team.team_id WHERE cfb_drive.red_zone_attempt = 1
GROUP BY team.name HAVING COUNT(*) > 10) AS overall on success.name = overall.name ORDER BY (success.count / overall.count) desc, success.name LIMIT 5;

/* 4. 10pts Which conference has the shortest games and how long are they on average? */
SELECT cfb_conference.name, AVG(duration) as duration FROM
cfb_conference, cfb_team, cfb_game, cfb_game_stats WHERE cfb_game_stats.game_id = cfb_game.game_id AND cfb_game.home_team_id = cfb_team.team_id AND cfb_team.conference_id = cfb_conference.conference_id
GROUP BY cfb_conference.conference_id ORDER BY AVG(duration) LIMIT 1;

/* 5. 10pts Which player had the most yards on 1st down in October. */
SELECT cfb_player.first_name, cfb_player.last_name FROM cfb_player,
(SELECT player_id, SUM(yards) FROM
((SELECT DISTINCT player_id, SUM(yards) as yards FROM cfb_rush, cfb_game, cfb_play WHERE cfb_rush.game_id = cfb_game.game_id AND cfb_rush.play_number = cfb_play.play_number AND cfb_play.game_id = cfb_game.game_id AND MONTH(cfb_game.game_date) = 10 AND cfb_play.down = 1
GROUP BY cfb_rush.player_id) UNION
(SELECT DISTINCT passer_player_id as player_id, SUM(yards) as yards FROM cfb_pass, cfb_game, cfb_play WHERE cfb_pass.game_id = cfb_game.game_id AND cfb_pass.play_number = cfb_play.play_number AND cfb_play.game_id = cfb_game.game_id AND MONTH(cfb_game.game_date) = 10 AND cfb_play.down = 1
GROUP BY cfb_pass.passer_player_id) UNION
(SELECT DISTINCT player_id, SUM(yards) as yards FROM cfb_reception, cfb_game, cfb_play WHERE cfb_reception.game_id = cfb_game.game_id AND cfb_reception.play_number = cfb_play.play_number AND cfb_play.game_id = cfb_game.game_id AND MONTH(cfb_game.game_date) = 10 AND cfb_play.down = 1
GROUP BY cfb_reception.player_id)) AS union_yards
GROUP BY player_id ORDER BY SUM(yards) desc LIMIT 1) as player_yards WHERE cfb_player.player_id = player_yards.player_id;

/* 6. 10pts From which state does Notre Dame receive most of its players? How many does that state send, and what percentage of ND players come from that state? */
SELECT homestate, COUNT(*) as cnt, COUNT(*) * 100.0 / SUM(COUNT(*)) over() as perc FROM
(SELECT DISTINCT player_id, homestate FROM cfb_player, cfb_team WHERE cfb_player.team_id = cfb_team.team_id AND cfb_team.name = 'Notre Dame' and cfb_player.homestate IS NOT NULL) as players
GROUP BY players.homestate ORDER BY COUNT(*) desc LIMIT 1;

/* 7. 5pts Players typically have only 4 years of eligibility to play in college. How many players have played for 3 or more teams? */
SELECT COUNT(*) FROM (SELECT COUNT(*) FROM cfb_player GROUP BY player_id HAVING COUNT(*) > 2) games;

/* 8. 10pts In 2010, the Big 10 Conference was the tallest conference on average. How much taller (on average) were they compared to the second tallest conference? */
SELECT heights.avg - prev AS height_diff FROM
(SELECT AVG(cfb_player.height) as avg, lag(AVG(cfb_player.height)) OVER(ORDER BY AVG(cfb_player.height)) as prev FROM
cfb_player, cfb_team, cfb_conference WHERE cfb_player.team_id = cfb_team.team_id AND cfb_team.conference_id = cfb_conference.conference_id AND cfb_team.year = 2010
GROUP BY cfb_conference.name ORDER BY AVG(cfb_player.height) desc) as heights LIMIT 1;

/* 9. 10pts Which stadium has witnessed their home team lose the most times? */
SELECT cfb_stadium.name, COUNT(*) as home_losses FROM cfb_play, cfb_game, cfb_stadium,
(SELECT cfb_play.game_id as game_id, MAX(cfb_play.play_number) as end_play FROM cfb_play
GROUP BY cfb_play.game_id) as game_max_plays WHERE cfb_play.game_id = game_max_plays.game_id AND cfb_play.play_number = end_play AND cfb_game.game_id = cfb_play.game_id AND cfb_stadium.stadium_id = cfb_game.stadium_id AND cfb_game.site = 'TEAM' AND
((cfb_game.home_team_id = cfb_play.offense_team_id AND cfb_play.offsense_points < cfb_play.defense_points) OR (cfb_game.home_team_id = cfb_play.defense_team_id AND cfb_play.defense_points < cfb_play.offsense_points))
GROUP BY cfb_stadium.stadium_id ORDER BY COUNT(*) DESC LIMIT 1;

/* 10. 15pts Which player(s) had the longest reception in the 4th quarter. What team where they on and what year was it? (breaking non-trivial ties is 5 of the 15 points, (i.e 10 points with LIMIT, 15 points without LIMIT) */
SELECT home_losses.first_name, home_losses.last_name, home_losses.name, home_losses.year FROM
(SELECT MAX(player_yards.yards) as max FROM
(SELECT DISTINCT cfb_player.first_name, cfb_player.last_name, cfb_team.name, YEAR(cfb_game.game_date) as year, cfb_reception.yards as yards FROM
cfb_reception, cfb_play, cfb_player, cfb_team, cfb_game WHERE cfb_reception.game_id = cfb_play.game_id AND cfb_reception.play_number = cfb_play.play_number AND cfb_reception.team_id = cfb_player.team_id AND cfb_reception.player_id = cfb_player.player_id AND cfb_team.team_id = cfb_player.team_id AND cfb_game.game_id = cfb_reception.game_id AND cfb_play.period = 4
ORDER BY cfb_reception.yards desc) as player_yards) as max_yards,
(SELECT DISTINCT cfb_player.first_name, cfb_player.last_name, cfb_team.name, YEAR(cfb_game.game_date) as year, cfb_reception.yards as yards FROM
cfb_reception, cfb_play, cfb_player, cfb_team, cfb_game WHERE cfb_reception.game_id = cfb_play.game_id AND cfb_reception.play_number = cfb_play.play_number AND cfb_reception.team_id = cfb_player.team_id AND cfb_reception.player_id = cfb_player.player_id AND cfb_team.team_id = cfb_player.team_id AND cfb_game.game_id = cfb_reception.game_id AND cfb_play.period = 4
ORDER BY cfb_reception.yards desc) as home_losses WHERE home_losses.yards = max_yards.max;

/* 11. 10pts What are the top 5 teams for total home-attendance? */
SELECT DISTINCT name, y, att FROM (SELECT home_team_id, CASE WHEN MONTH(game_date) = 1 THEN (YEAR(game_date) - 1) ELSE YEAR(game_date) END as y, SUM(attendance) as att FROM
(SELECT home_team_id, game_date, attendance FROM cfb_game, cfb_game_stats WHERE cfb_game.game_id = cfb_game_stats.game_id) as total
GROUP BY home_team_id, y ORDER BY att DESC LIMIT 5) as total LEFT JOIN cfb_team ON total.home_team_id = cfb_team.team_id;
