CREATE TABLE `bookings` (
	`id` text PRIMARY KEY NOT NULL,
	`event` text NOT NULL,
	`user` text NOT NULL,
	`name` text NOT NULL,
	`email` text NOT NULL,
	`status` text NOT NULL,
	`expires` integer DEFAULT 0 NOT NULL,
	`created` integer NOT NULL,
	`checked` integer DEFAULT 0 NOT NULL,
	FOREIGN KEY (`event`) REFERENCES `events`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE UNIQUE INDEX `event_user` ON `bookings` (`event`,`user`);--> statement-breakpoint
CREATE INDEX `event_status` ON `bookings` (`event`,`status`,`created`);--> statement-breakpoint
CREATE TABLE `events` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`title` text NOT NULL,
	`description` text NOT NULL,
	`category` text NOT NULL,
	`location` text NOT NULL,
	`starts` integer NOT NULL,
	`capacity` integer NOT NULL,
	`status` text DEFAULT 'open' NOT NULL,
	`theme` integer DEFAULT 0 NOT NULL,
	`kind` text DEFAULT 'event' NOT NULL,
	`created` integer NOT NULL
);
