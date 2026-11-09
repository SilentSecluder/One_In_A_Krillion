// Unload all sprites that are off-screen, unload all backgrounds that are not actively being called up for the scene/knot in question
// sprites, besides the animated shrimp, should always be behind the narration bar
// all sprites referenced are the names of their spritesheet files, just missing the .png marker
// all speaking characters should be formatted as such on the narration bar:
//  [Name]:
//  [Text]
// the name will be stagnant at the top of the bar, the text will change and grow depending on what is said.
// between each background switch, there should be a simple fade-to-black animation that reverses and loades the new background underneath it. This animation covers the background and the sprites, but not the narration bar and the animated shrimp
// all sprites, except the animated shrimp, should unload when backgrounds switch, unless otherwise specified

->HatcheryIntro
==HatcheryIntro==
//load background "Hatchery_Background.png"
// move Worker_1 sprite on middle-left side of screen from left-side off-screen, Worker_2 on middle-right side of screen from right-side off-screen
Worker 1: God, these shrimp look so good. When are they being sold again? 
Worker 2: I don't know, in a few days?
Worker 2: And dude, these are live shrimp. How can they possibly look good?
Worker 1: They don't look so different from ceviche shrimp.
Worker 2: ..You're crazy.
Worker 1: Please tell me the difference between these and ceviche.
Worker 2: Dude, they're still ALIVE!
Worker 1: Okay, so they're just a bit raw, what's you're point?
Worker 2: God, I need to quit this job.
Worker 2: Can you just pour their meal in already?
Worker 1: Yeah yeah, already on it.
[A bag is unzipped above the tank.]
Worker 2: Why is it so green, are you sure you grabbed the right stuff?
Worker 1: Of course I did, they have some special meal plan or something, I don't really know.
Worker 2: Whatever. Just hurry up.
[The plattering of small pellets rattles through the hatchery.]
Worker 1: Dangit.. I just got these shoes!
Worker 2: How did you even manage to spill it-
Worker 2: Dude, they're pellets. Just brush them off?
Worker 1: No but they're like green and weird and kind of sticky.
Worker 2: I'm so done with this place.
[Someone walks away from the tank.]
// animate Worker_2 sprite walking off to the right side of the screen, stopping at edge of screen
Worker 1: Stupid, stupid. 
Worker 1: Hey, are you going to make me clean this up all by myself?
Worker 2: Yeah, you spilt it, not me.
Worker 1: But you work here too!
Worker 2: Not with that attitude.
Worker 1: ..What on earth does that mean.
Worker 2: ...Nothing, I'm going to check the tuna storage.
// animate Worker_2 sprite walking off to the right side of the screen
Worker 1: Yeah okay.
[The sound of sweeping is heard from outside the tank.]
Worker 1: ..What are they feeding you guys, the tank is glowing.
Worker 1: Kind of reminds me of a Chernobyl documentry.
Worker 1: Smells weird too.
Worker 1: Anyways.
[Someone starts whistling and walking away from the tank.]
// animate Worker_1 sprite walking off the right side of the screen
->TransformationScene

==TransformationScene==
//continue loading background "Hatchery_Background.png"
Narrator: You are a shrimp.
Narrator: Until now, you were just swarming around in a tank.
Narrator: But, for some reason, after eating too many of the new pellets, you've become aware.
Narrator: Perhaps too aware.
Narrator: The shrimp around you, they did not change.
Narrator: It seems, in your gluttony, you have gained a form of consciousness they could never hope to.
Narrator: It is unlikely they hope for anything, though. After all, they're just shrimp.
Narrator: But, you are a very smart shrimp. You will not succumb to the same fate as them.
Narrator: That is, if you want to survive.
Narrator: Do you want to become ceviche?
*   Yes.

[Footsteps sound outside the tank.]
// sprite Worker_2 moves in from right side of screen, sprite Chef follows immediately after, stopping with Worker_2 on the middle-left of the screen, and Chef on middle-right of the screen
Chef: What's in this tank?
Worker 2: High quality shrimp, ma'am.
Chef: What about them is high quality, they seem pretty average for shrimp?
Worker 2: Well, we supply them with an enriched diet free of growth hormones and unnatural chemicals.
Chef: That's certainly pretty high quality then. Hm..
[You can suddenly see the Chef's face against the tank, peering through the glass.]
// sprite Chef moves to center of screen, then zooms in on the pixels outlining the sprites face
[The Chef's eyes widen when it locks onto you.]
Chef: That's an all natural shrimp? It's beautiful and perfectly sized. Your hatchery has some astounding specimens.
Chef: We'll take this batch, unless you already have a buyer?
Worker 2: Oh perfect! Their original buyer backed out a few days ago, so this is wonderful timing for us.
Worker 2: Come with me to the front desk, we can get it all sorted out there.
Chef: Lovely, they will taste delicious for this weekends dinner.
[The Chef's face disappears from the glass, and the sound of footsteps vanishes off in the distance.]
// reverse Chef sprite zoom in animation, then sprite Worker_2 and Chef move off of right side of screen
        ->SushiParlor
*   No.

[Footsteps sound outside the tank.]
// sprite Worker_2 moves in from left side of screen, sprite Chef follows immediately after
Chef: What's in this tank?
Worker 2: High quality shrimp, ma'am.
Chef: What about them is high quality, they seem pretty average for shrimp?
Worker 2: Well, we supply them with an enriched diet free of growth hormones and unnatural chemicals.
Chef: That's certainly pretty high quality then. Hm..
[You can suddenly see the Chef's face against the tank, peering through the glass.]
// sprite Chef moves to center of screen, then zooms in on the pixels outlining the sprites face
Chef: I don't know, they're not too special to me. Can I see your other stock?
Worker 2: Sure, follow me.
[The Chef's face disappears from the glass, and the sound of footsteps vanishes off in the distance.]
// reverse Chef sprite zoom in animation, then sprite Worker_2 and Chef move off of right side of screen
        ->FeedStore

==SushiParlor==
// load background "SushiParlor_Background.png"
// sprite Chef moves in from left side of screen, stopping at middle-left of the screen
Chef: Oh! The shrimp are here.
[You find yourself in a new tank, though you're not exactly sure where.]
Chef: Wheres that boy, I need these shrimp wheeled inside?
Jordan: ...
Chef: BOY! GET OVER HERE!
// sprite Jordan moves in from right side of screen, 1.4 times faster than standard sprite movement only for this specific animation, stopping at middle-right of the screen
Jordan: I'm here chef, where do you want them?
Chef: Place them in the walk-in freezer for now.
Jordan: Yes chef.
// sprite Jordan moves next to sprite Chef
[The tank suddenly shakes as you're pushed into a different room.]
// sprite Jordan moves at half animation speed across the screen, stopping at the right edge, sprite Chef moves the opposite direction at the same speed, ending up off-screen
Jordan: Great.. Now I need to go out and get some other seafood for the main course.
[Footsteps move away from the tank, leaving you all alone.]
// sprite Jordan moves to the left at normal speed, ending up off-screen
Narrator: Well, this is interesting.
Narrator: It seems you might become ceviche after all.
Narrator: Are you satisfied with this ending?

*   Yes.

Narrator: You're quite an odd fellow, little shrimp.
Narrator: Perhaps you should get to know your shrimp friends a bit better before you all become food.
Narrator: Or, you don't have to. I don't control the shrimp.
[It's getting pretty cold in the tank.]
Narrator: You're probably going to fall asleep soon.
Narrator: Have a nice nap, little shrimp.
[You fall asleep in the tank.]
// sprite Chef moves in from the left side of the screen, stopping at the middle-right of the screen. Sprite Jordan follows behind sprite chef, stopping at the middle-left of the screen
Chef: Alright, the shrimp are ready to be prepared.. Give me that big one for the main plate.
Jordan: Yes chef.
Chef: And, done. This will make a perfect meal.
    ->DONE

*   No.

Narrator: It won't change much at this rate, I fear.
Narrator: ...Wait, what are you doing?
Narrator: Swimming out of the tank? Will you even make it?
[There's a wet slap of something hitting the ground.]
Narrator: ..Well I'll be damned.
Narrator: There's a storm drain to your right, make a run for it.
[The sound of rapid scurrying across the floor echoes through the freezer.]
[There's a splash as you fall into the drain.]
    ->Ocean

==Ocean==
// load background "Ocean_Background.png"
Narrator: How did you even do this.. 
Narrator: Well, you're in the ocean now.
Narrator: Where do you plan to go?

*   Into the open sea.
        ->OpenSea
        
==OpenSea==
// continue loading background "Ocean_Background.png"
Narrator: Okay then, you hop into a current above you, and you'll be there.
Narrator: ..It might be a bit of a ride, though.
Narrator: I hope you can dodge fish.
Narrator: Oh my, look ahead!
// Fade sprite Swarm into the middle of the screen in a 1.5 second animation
[You see a massive swarm of shrimp and krill alike out in the distance.]
Narrator: Those are wild shrimp, do you want to join them?


->DONE

==FeedStore==
// load background "FeedStore_Background.png"
// sprite Shop_Attendant will already be on the left edge of the screen, covered by the fade in of the background
Narrator: At some point, you must've taken quite the nap.
Narrator: You're not in the hatchery anymore.
[A bell dings loudly in the distance.]
// sprite Jordan moves in from the right side of the screen, stopping at the middle-right of the screen
Shop Attendant: Welcome in!
Jordan: ...
Shop Attendant: ...
Jordan: ...
Jordan: Do you have anything that can be turned into seafood pretty quickly?
Shop Attendant: Well.. um.
Shop Attendant: Most of our fish aren't very uh.. edible.
Shop Attendant: Oh! There's our shrimp though, back there.
Jordan: ...
// sprite jordan moves to the middle of the screen, then zooms in slightly towards his face
[Someone loudly walks over to the tank.]
Jordan: That will do.
[The bell dings again.]
// sprite Saoirse moves in from the right side of the screen, stopping at the right edge
Shop Attendant: Great.. Welcome in!
Saoirse: ...Thanks for having me.
Shop Attendant: Always! Is there anything I can help you with?
// sprite Saoirse crosses the screen behind sprite Jordan to stand a few pixels away from sprite Shop_Attendant
Saoirse: Um.. Yes please. I need a shrimp for an art piece- I promise it's not weird or anything, I was just told that shrimp are good subjects and it'd be great practice and-
Shop Attendant: Don't worry a thing about it, we just got a fresh supply back there by the well-dressed gentleman.
Saoirse: Oh uhm.. Thank you.
// sprite Shop_Attendant crosses the screen behind sprite Jordan and sprite Saoirse to the middle-right of the screen
// sprite Saoirse moves to the left edge of the screen, then zooms in slightly towards her face, just less so than sprite Jordan
[A very quiet set of footsteps makes their way towards the tank.]
Jordan: ...
Saoirse: ...
Saoirse: Um.. Are you getting some shrimp?
Jordan: ...
Saoirse: ...
Jordan: Yes, my boss needs a lot for a company event.
Saoirse: Oh.. all of them?
Jordan: Most likely.
Saoirse: ...
Jordan: ...
Jordan: Why, do you need some?
Saoirse: Well um, just one- for drawing practice.
Jordan: Hm.
Narrator: This is getting painful to listen to.

*   Make yourself visible.

Saoirse: Oh my, that one is beautiful.
Jordan: ...It looks unhealthy.
Saoirse: ...
Saoirse: Then it just needs some support!
Jordan: ...
Jordan: If you really need a shrimp, that one is all yours.
Saoirse: Are you sure? Don't you need all the shrimp you can get for the event?
Jordan: The head chef will throw me out if I hand him that shrimp, it's yours.
Saoirse: Oh, thank you! I'm sure you'll do great with your work.
Jordan: ...
// sprite Saoirse zooms back out to original scale
[Footsteps start to quickly move away.]
Jordan: I hope your art goes well.
// sprite Saoirse crosses the room behind sprite Jordan to stand next to sprite Shop_Attendant
Shop Attendant: Oh, Saoirse! Find what you need?
Saoirse: Yes, there's this beautiful shrimp in there that would be wonderful to paint.
Shop Attendant: Well that's amazing! I'll get it out and then it's all yours.
Saoirse: Amazing, thanks so much, I hope I'm not being a problem by always having you get them for me.
// sprite Shop_Attendant crosses the screen behind sprite Jordan and sprite Saoirse, stopping at the middle-left of the screen, then zooming in to the same scale as sprite Jordan, but focused on the middle of the sprite rather than the face
Shop Attendant: Not a problem for my favorite customer!
Saoirse: Guh.
[You are suddenly pulled out of the tank by a net, then placed into a plastic bag.]
// sprite Shop_Attendant zooms back out to original scale, then crosses the screen again behind sprite Jordan and sprite Saoirse, stopping at the right edge of the screen
Shop Attendant: Okay, five dollars, fourteen cents and it's all yours.
[The sound of loose coins hits the counter.]
Shop Attendant: Perfect, you're all set. Have a nice day!
Saoirse: Thanks, you too!
    -> StreetsSaoirse

*   Stay in the corner of the tank.

Saoirse: ...
Jordan: Hey, Shopkeep?
Shop Attendant: Yes?
Jordan: I'd like the full stock.
Shop Attendant: Ah.. Alright. Give me a moment.
Saoirse: ...Mm
// sprite Saoirse zooms out to original scale, then crosses behind sprite Jordan and in front of sprite Shop_Attendant, moving off the right edge of the screen
[Someone quietly walks away from the tank, a bell ringing in the distance.]
Shop Attendant: Alright. I'm going to have to take a few minutes to drain the tank and make sure I get all the shrimp.
// sprite Shop_Attendant crosses the screen behind sprite Jordan, stopping at the middle-left of the screen, then zooming in to the same scale as sprite Jordan, but focused on the middle of the sprite rather than the face
[A tube is suddenly placed before you, yanking you up into its current.]
Shop Attendant: There they go.
Jordan: ...
[You're dropped into a giant bucket, many of your shrimp brethren falling behind you.]
Jordan: How long exactly will this take?
Shop Attendant: Just a minute or two longer, I promise.
Jordan: ...
[The machine-powered current suddenly stops.]
Shop Attendant: And done. This bucket is yours the second you pay...
Shop Attendant: Two-Hundred-seventy-four dollars and thirty-seven cents.
Jordan: ...Pricy.
Shop Attendant: They're high-quality shrimp.
Jordan: Right.
// sprite Jordan and sprite Shop_Attendant zoom back out to their original scale, Jordan crosses to the right edge of the screen and stops there, Shop_Attendant follows and stops a few pixels to the left of Jordan
[The sound of plastic tapping electronics echoes outside.]
Shop Attendant: ..All set. Have a nice day, sir.
Jordan: Thanks.
    ->StreetsJordan

*   Cause a scene.

[You start swarming very fast.]
Saoirse: Hey uh..
Shop Attendant: Whats up?
Saoirse: ...
Jordan: ..Your shrimp. They're fast.
Shop Attendant: Yes, is that a problem?
[The sound of metal slamming against wood is heard.]
Jordan: The tank is shaking.
// sprite Shop_Attendant moves to the middle-right of the screen, crossing in front of sprite Jordan and sprite Saoirse then zooming in to the same scale as sprite Jordan, but focused on the middle of the sprite rather than the face
[Someone walks over, two hands placed on the tank suddenly holding it in place.]
Shop Attendant: Well, that's a new issue.
Saoirse: ...
Saoirse: I'm going to walk down to the other store.
Jordan: I think I'll be following you.
Shop Attendant: That uh.. God- might be for the best.
// sprite Jordan and sprite Saoirse both zoom out to their original scale, sprite Saoirse crossing the screen and moving off the right edge, sprite Jordan following directly behind and also moving off the right edge of the screen
[Two sets of footsteps move away from the tank, the bell dings in the distance.]
Shop Attendant: Ridiculous, you shrimp suck.
Shop Attendant: ..Oh, but that big one is cool. 
    ->ShopAttendantCounter

==ShopAttendantCounter==
// load background "ShopAttendantCounter_Background.png"
e
->DONE

==StreetsJordan==
// load background "Streets_Background.png"
e
->DONE
==StreetsSaoirse==
// load background "Streets_Background.png"
e
->DONE