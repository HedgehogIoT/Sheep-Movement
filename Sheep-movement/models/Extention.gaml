/**
* Name: Sheep Herding
* Description: Sheep move as a herd using cohesion, alignment, separation,
* and follow a shepherd while avoiding obstacles.
* Tags: ABM, herding, sheep
*/

model sheep_herding

global {
	// Population
	int number_of_sheep <- 50 min: 1 max: 500;
	int number_of_obstacles <- 5 min: 0;

	// Movement
	float maximal_speed <- 5.0 min: 0.1 max: 10.0;
	float minimal_distance <- 20.0;

	// Herding factors
	int cohesion_factor <- 150;
	int alignment_factor <- 100;

	// Environment
	int world_size <- 1000;
	int bounds <- int(world_size / 20);
	
	bool apply_cohesion <- true;
	bool apply_alignment <- true;
	bool apply_separation <- true;
	bool apply_avoidance <- true;

	int xmin <- bounds;
	int ymin <- bounds;
	int xmax <- world_size - bounds;
	int ymax <- world_size - bounds;
	image_file images  <- image_file('../includes/sheep.png');
	image_file images1 <- image_file('../includes/happy.png');
	geometry shape <- square(world_size);
	
	// Obstacle size range
	float obstacle_min_size <- 10.0;
	float obstacle_max_size <- 60.0;

	// Move shepherd with mouse
	action move_shepherd {
		ask first(shepherds) {
			do goto target: #user_location speed: 10.0;
		}
	}
	
	init {
		create sheep number: number_of_sheep {
			location <- {rnd(world_size), rnd(world_size)};
		}
		// Fixed obstacle (wall)
		// Fixed vertical wall
		create obstacle {
			fixed <- true;
			shape <- rectangle(10, 200);
			location <- {300, 250};   // center of y = 0 → 500
		}
		
		// Random obstacle
		create obstacle number: number_of_obstacles {
			location <- {rnd(world_size), rnd(world_size)};
			shape <- square(size);
			fixed <- false;
		}
		create vegetables number: 10 {
			location <- {rnd(world_size), rnd(world_size)};
		}
		create shepherds number: 1 {
			location <- {world_size / 2, world_size / 2};
		}
		create dog number: 1 {
			location <- {world_size / 2, world_size / 2};
		}
		
	}
}
grid land width: world_size height: world_size neighbors: 4 {
	int trampling <- 0;
	grid land {
	draw square(cell_size) color: rgb(0, 255 - trampling, 0);
}
	
}
species vegetables {
	aspect default {
		draw circle(10) color: #green;
	}
}
/////////////////////////////////////////////////////
// Shepherd
/////////////////////////////////////////////////////

species shepherds skills: [moving] {
	reflex wander {
		do wander amplitude: 90 speed: 5;
	}

	aspect default {
		draw circle(10) color: #red;
		draw circle(60) color: #orange wireframe: true;
	}
}

/////////////////////////////////////////////////////
// Sheep
/////////////////////////////////////////////////////

species sheep skills: [moving] {
	float body_size <- 8.0;
	float food_distance <- body_size * 2;
	bool eating <- false;
	int eating_time <- 0;
	int eating_duration <- 5; // 5 cycles = 5 seconds
	
	float path_perception <- 30.0;   // how far sheep see paths
	float path_weight <- 0.3;        // how strong path attraction is
	
	float speed max: maximal_speed <- maximal_speed;
	float perception_range <- minimal_distance * 2;
	point velocity <- {0, 0};

	// Separation: keep distance
	reflex separation when: apply_separation {
		point acc <- {0, 0};
		ask (sheep overlapping circle(minimal_distance)) {
			acc <- acc - (location - myself.location);
		}
		velocity <- velocity + acc;
	}

	// Alignment: match direction
	reflex alignment when: apply_alignment {
		list<sheep> neighbors <- (sheep overlapping circle(perception_range)) - self;
		if (length(neighbors) > 0) {
			point avg_vel <- mean(neighbors collect each.velocity);
			velocity <- velocity + ((avg_vel - velocity) / alignment_factor);
		}
	}

	// Cohesion: stay together
	reflex cohesion when: apply_cohesion {
		list<sheep> neighbors <- (sheep overlapping circle(perception_range)) - self;
		if (length(neighbors) > 0) {
			point center <- mean(neighbors collect each.location);
			velocity <- velocity + ((center - location) / cohesion_factor);
		}
	}

	// Avoid obstacles
	reflex avoid_obstacles when: apply_avoidance {
		point acc <- {0, 0};
		ask (obstacle overlapping circle(perception_range)) {
			acc <- acc - (location - myself.location);
		}
		velocity <- velocity + acc;
	}

	// Follow shepherd
	reflex follow_shepherd {
		point target <- first(shepherds).location;
		velocity <- velocity + ((target - location) / cohesion_factor);
	}
	
	reflex go_to_vegetables {

		list<vegetables> nearby_food <- (vegetables as list) where (
		each.location distance_to location <= food_distance
	);

		if length(nearby_food) > 0 {
			vegetables target <- one_of(nearby_food);
			velocity <- velocity + ((target.location - location) / cohesion_factor);
		}
	}
	
	reflex start_eating when: !eating {

		list<vegetables> touching_food <- (vegetables as list) where (
			each.location distance_to location <= body_size
		);

		if length(touching_food) > 0 {
			eating <- true;
			eating_time <- 0;
			velocity <- {0, 0};
			write "Sheep " + name + " started eating at " + location;
		}
	}
	
	reflex flee_dog {

		list<dog> nearby_dogs <- (dog as list) where (
			each.location distance_to location <= 80
		);
	
		if length(nearby_dogs) > 0 {
			dog threat <- one_of(nearby_dogs);
			velocity <- velocity - ((threat.location - location) / 10);
		}
	}

	// Keep sheep inside world
	action bounding {
		if location.x < xmin { velocity <- velocity + {bounds, 0}; }
		if location.x > xmax { velocity <- velocity - {bounds, 0}; }
		if location.y < ymin { velocity <- velocity + {0, bounds}; }
		if location.y > ymax { velocity <- velocity - {0, bounds}; }
	}
	

	// Move
	reflex move {
		if velocity = {0,0} {
			velocity <- {rnd(3)-1, rnd(3)-1};
		}
		point old_loc <- location;
		do goto target: location + velocity;
		velocity <- location - old_loc;
		do bounding;
		create footprint {
			location <- myself.location;
		}
		
	}
	reflex follow_paths {

	list<footprint> nearby_paths <- footprint
		where (each.location distance_to location < path_perception);

	if length(nearby_paths) > 0 {

		point path_center <- mean(nearby_paths collect each.location);

		velocity <- velocity
			+ (path_center - location) * path_weight;
	}
}
	

	aspect default {
		draw images size: {50,50} border: #black;
	}
}

/////////////////////////////////////////////////////
// Dog
/////////////////////////////////////////////////////

species dog skills: [moving] {

	float speed <- 6.0;
	float scare_distance <- 80.0;

	reflex chase_sheep {
		sheep target <- one_of(sheep);
		do goto target: target.location speed: speed;
	}

	aspect default {
		draw images1 size: {50,50} border: #black;
		draw circle(scare_distance) color: #red wireframe: true;
	}
}

/////////////////////////////////////////////////////
// Obstacles
/////////////////////////////////////////////////////

species obstacle {
	
	float size <- rnd(obstacle_min_size, obstacle_max_size);
	bool fixed <- false;

	aspect default {
		draw shape color: fixed ? #yellow : #brown;
	}
}

species footprint {
	int age <- 0;

	reflex aging {
		age <- age + 1;
		if age > 500 { do die; }
	}
	
	aspect default {
		draw circle(1) color: #red;
	}
}





/////////////////////////////////////////////////////
// Experiment
/////////////////////////////////////////////////////

experiment "Sheep Herding" type: gui autorun: true {

	parameter "Number of sheep" var: number_of_sheep;
	parameter "Minimal distance" var: minimal_distance;
	parameter "Cohesion factor" var: cohesion_factor;
	parameter "Alignment factor" var: alignment_factor;

	output {
		display Field type: 2d axes: false background: #brown {
			grid land border: #black;
			species footprint;
			
			species sheep;
			species vegetables;
			species shepherds;
			species obstacle;
			species dog;
			
			event #mouse_move {
				ask simulation { do move_shepherd; }
			}
		}
	}
}
