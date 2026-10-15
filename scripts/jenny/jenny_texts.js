/**
 * OOPA Virtual Labs – Jenny Agu Dialog Content
 *
 * Messages are organised by page key. Each page has an ordered list of items:
 *   id    – stable, unique id (used for "don't show again")
 *   type  – info | caution | warning
 *   title – short heading
 *   text  – plain text (rendered with textContent, never as HTML)
 *
 * Page keys are chosen by <script data-page="..."> on each HTML page.
 * Voice: professional, first/second person.
 *
 * SECURITY: never put credentials, passcodes or other secrets in this file.
 */

"use strict";

(function (global) {
  function labPage(key, name, topics) {
    return {
      page_name: key,
      page_convo: [
        {
          id: key + "-welcome",
          type: "info",
          title: name + " Laboratory",
          text: "Welcome to the " + name + " Laboratory. This space is being prepared for interactive experiments on " + topics + "."
        },
        {
          id: key + "-status",
          type: "caution",
          title: "Under Construction",
          text: "The scientific model and interactive controls for this laboratory have not been implemented yet. Return to the main menu to explore other laboratories."
        }
      ]
    };
  }

  const JENNY_TEXTS = {
    // Welcome splash (also usable as a general intro sequence)
    welcome: {
      page_name: "welcome",
      page_convo: [
        {
          id: "welcome-intro",
          type: "info",
          title: "Welcome",
          text: "Hello. I am Jenny Agu, your on-screen guide for OOPA Virtual Labs. I will help you find your way around the laboratories and understand what each one offers."
        },
        {
          id: "welcome-assist",
          type: "info",
          title: "How I Assist You",
          text: "You will find me on every page. Use the round button in the lower-right corner to open or close me at any time, and I will appear on my own when there is something worth knowing."
        }
      ]
    },

    "main-menu": {
      page_name: "main-menu",
      page_convo: [
        {
          id: "menu-choose",
          type: "info",
          title: "Choose a Laboratory",
          text: "Select any laboratory card to enter it: Physics, Chemistry, Biology, Mathematics or Engineering. Start with whichever field interests you most."
        },
        {
          id: "menu-progress",
          type: "caution",
          title: "Platform in Development",
          text: "OOPA Virtual Labs is a growing platform. Some laboratories are still placeholders while their interactive models are being built."
        },
        {
          id: "menu-more",
          type: "info",
          title: "More to Come",
          text: "New laboratories will be added over time. The \u201cMore to come\u201d card shows what is planned next."
        }
      ]
    },

    "admin-login": {
      page_name: "admin-login",
      page_convo: [
        {
          id: "adminlogin-purpose",
          type: "info",
          title: "Administrator Access",
          text: "This page is for administrators only. Learners do not need to sign in; they can explore every laboratory from the main menu."
        },
        {
          id: "adminlogin-demo",
          type: "caution",
          title: "Demonstration Login",
          text: "This sign-in is a prototype check that runs in your browser and is not secure. Server-side authentication must be added before the platform is deployed."
        }
      ]
    },

    "admin-dashboard": {
      page_name: "admin-dashboard",
      page_convo: [
        {
          id: "admin-overview",
          type: "info",
          title: "Dashboard Overview",
          text: "This dashboard summarises the platform: laboratory categories, lab pages and overall status. Use the sidebar to move between sections."
        },
        {
          id: "admin-logout",
          type: "caution",
          title: "Signing Out",
          text: "Use the log-out button at the bottom of the sidebar when you finish, especially on a shared computer."
        }
      ]
    },

    physics: {
      page_name: "physics",
      page_convo: [
        {
          id: "physics-welcome",
          type: "info",
          title: "Physics Laboratory",
          text: "This is the Physics hub. Each card is a project you can open. Particle Motion and Projectile Motion are available now, and more projects can be added alongside them."
        },
        {
          id: "physics-more",
          type: "caution",
          title: "More Projects Planned",
          text: "Motion, forces, energy and heat are all on the roadmap. Projects that are not yet built appear as planned cards."
        }
      ]
    },

    "particle-motion": {
      page_name: "particle-motion",
      page_convo: [
        {
          id: "pm-intro",
          type: "info",
          title: "Particle Motion",
          text: "Each dot is a particle bouncing around a box. Faster particles look redder. Press Pause to freeze the motion, or Step to advance a moment at a time."
        },
        {
          id: "pm-temperature",
          type: "info",
          title: "Temperature and Pressure",
          text: "Raise Temperature and every particle speeds up. Watch the average speed and the wall pressure rise together. Pressure is the push the particles give the walls."
        },
        {
          id: "pm-gravity",
          type: "caution",
          title: "Gravity and Elasticity",
          text: "With gravity on and elasticity below 1, each bounce loses energy and the particles settle at the bottom. Set elasticity to 1 to keep the total energy constant."
        },
        {
          id: "pm-histogram",
          type: "info",
          title: "Speed Distribution",
          text: "The bars show how many particles move at each speed. With collisions on and gravity off, they settle onto the dashed Maxwell\u2013Boltzmann curve. Try Reset and watch it happen."
        },
        {
          id: "pm-limits",
          type: "caution",
          title: "A Simplified Model",
          text: "This is a two-dimensional model with identical, frictionless discs. It captures the main ideas of gas behaviour but not every detail of a real gas."
        }
      ]
    },
    "projectile-motion": {
      page_name: "projectile-motion",
      page_convo: [
        {
          id: "pj-intro",
          type: "info",
          title: "Projectile Motion",
          text: "Set the launch speed, angle and height, then press Launch. The red dot is the projectile and the green arrow shows its velocity. Step moves it forward a moment at a time."
        },
        {
          id: "pj-ideal",
          type: "info",
          title: "Ideal Against Real",
          text: "The dashed grey path is what the textbook formulas predict with no air. The table under the picture compares its range, flight time and height with your simulation."
        },
        {
          id: "pj-angle",
          type: "info",
          title: "Which Angle Is Best?",
          text: "With no air, the longest range comes at 45 degrees. With air drag the best angle is lower. Try the Air drag preset and search for it."
        },
        {
          id: "pj-energy",
          type: "caution",
          title: "Energy Is Not Always Conserved",
          text: "In a vacuum the total energy stays flat. Drag and inelastic bounces turn some of it into heat, so the black line on the energy graph falls."
        },
        {
          id: "pj-ground",
          type: "caution",
          title: "Bounce and Friction",
          text: "With bounciness at 0 the projectile does not rebound. Friction removes horizontal speed at each impact and then slows the projectile as it rolls to a stop."
        },
        {
          id: "pj-limits",
          type: "caution",
          title: "A Simplified Model",
          text: "The projectile is a point in two dimensions, and drag grows with the square of speed. Spin and changes in air density with height are ignored."
        }
      ]
    },
    chemistry: {
      page_name: "chemistry",
      page_convo: [
        {
          id: "chemistry-welcome",
          type: "info",
          title: "Chemistry Laboratory",
          text: "Ten chemistry projects are available, including Chemical Reactions with a periodic-table picker."
        },
        {
          id: "chemistry-more",
          type: "caution",
          title: "More Projects Planned",
          text: "Reactions, equilibrium and materials are on the roadmap. Projects that are not yet built appear as planned cards."
        }
      ]
    },
    titration: {
      page_name: "titration",
      page_convo: [
        {
          id: "ti-intro",
          type: "info",
          title: "Titration",
          text: "Add titrant from the burette to the flask and watch the pH. The flask changes colour when the indicator reaches its transition range, and the curve builds as you go."
        },
        {
          id: "ti-slow",
          type: "info",
          title: "Go Slowly Near the End",
          text: "The pH changes very fast close to the equivalence point. Switch from millilitres to single drops as the colour begins to change."
        },
        {
          id: "ti-eq",
          type: "info",
          title: "Equivalence and Endpoint",
          text: "The equivalence point is where the acid and base have exactly reacted. The endpoint is where the indicator changes colour. A good indicator puts the two very close together."
        },
        {
          id: "ti-weak",
          type: "caution",
          title: "Weak Acids and Bases",
          text: "A weak acid starts at a higher pH and has a smaller jump, and its equivalence point is above 7. Try methyl orange with a weak acid and see how early it changes."
        },
        {
          id: "ti-unknown",
          type: "info",
          title: "Unknown Mode",
          text: "Tick Unknown flask solution, find the endpoint, record it, then calculate the strength from the volume you added. Press Check answer to see how close you were."
        },
        {
          id: "ti-model",
          type: "caution",
          title: "A Simplified Model",
          text: "The pH is calculated exactly at 25 degrees Celsius for a one-to-one reaction, ignoring activity effects. Very strong solutions may differ slightly from a real meter."
        }
      ]
    },
    "gas-laws": {
      page_name: "gas-laws",
      page_convo: [
        {
          id: "gl-intro",
          type: "info",
          title: "Gas Laws",
          text: "Choose a law, then change the one control that is left free. The gauge shows the pressure of the gas, and the moving dots show its particles."
        },
        {
          id: "gl-held",
          type: "info",
          title: "What Is Held Constant",
          text: "Each law holds two quantities fixed. The note under the chamber and the greyed-out sliders show which ones. The remaining quantity responds to your change."
        },
        {
          id: "gl-record",
          type: "info",
          title: "Collect Data",
          text: "Press Record data point at several settings. The last column of the table should stay the same in every row. That constant is the law."
        },
        {
          id: "gl-kelvin",
          type: "caution",
          title: "Use Kelvin",
          text: "Gas laws need absolute temperature in kelvin. Zero degrees Celsius is 273 K. Using Celsius would give the wrong ratios."
        },
        {
          id: "gl-limit",
          type: "caution",
          title: "Piston Limits",
          text: "The piston can only move between 2 and 30 litres. When a law pushes it to a limit, the control stops there and a note appears."
        },
        {
          id: "gl-model",
          type: "caution",
          title: "An Ideal Gas",
          text: "The pressure comes from the ideal gas law. The particles do not attract each other or take up space, and the dots are an illustration. Real gases follow these laws closely, except at high pressure or low temperature."
        }
      ]
    },
    biology: {
      page_name: "biology",
      page_convo: [
        {
          id: "biology-welcome",
          type: "info",
          title: "Biology Laboratory",
          text: "This is the Biology hub. Each card is a project you can open. Cell Diffusion and Osmosis, Single-Celled Organisms, Predator\u2013Prey Populations and Ecosystems are available now, and more projects can be added alongside them."
        },
        {
          id: "biology-more",
          type: "caution",
          title: "More Projects Planned",
          text: "Natural selection and body systems are on the roadmap. Projects that are not yet built appear as planned cards."
        }
      ]
    },
    "cell-diffusion-osmosis": {
      page_name: "cell-diffusion-osmosis",
      page_convo: [
        {
          id: "cdo-intro",
          type: "info",
          title: "Two Experiments",
          text: "Choose Diffusion or Osmosis on the right, adjust the controls, and watch the particles and the graph. Reset starts the experiment again."
        },
        {
          id: "cdo-diffusion",
          type: "info",
          title: "Diffusion",
          text: "Particles spread from where they are crowded to where they are scarce. Even when the two sides are equal, particles keep crossing both ways, so the net movement is zero."
        },
        {
          id: "cdo-size",
          type: "info",
          title: "Membrane and Molecule Size",
          text: "Only small molecules fit through the pores. Compare oxygen, glucose and starch, and try closing the membrane."
        },
        {
          id: "cdo-osmosis",
          type: "info",
          title: "Osmosis",
          text: "Water moves across the cell membrane toward the side with more dissolved solute. Compare the solution outside with the 300 milliosmoles per litre inside the cell."
        },
        {
          id: "cdo-tonicity",
          type: "caution",
          title: "Weak and Strong Solutions",
          text: "In a weak solution an animal cell swells and can burst. In a strong one it shrinks and crinkles. A plant cell has a wall, so it becomes firm instead of bursting."
        },
        {
          id: "cdo-model",
          type: "caution",
          title: "A Simplified Model",
          text: "The particles are a schematic picture. Cell volume follows a simple water-flow rule, and the 300 inside value is typical of animal cells, not an exact measurement."
        }
      ]
    },

    "ecosystem": {
      page_name: "ecosystem",
      page_convo: [
        {
          id: "eco-intro",
          type: "info",
          title: "Living Ecosystems",
          text: "Each circle is a store of matter and each arrow is matter moving each year. Bigger circles hold more and thicker arrows carry more."
        },
        {
          id: "eco-cycle",
          type: "info",
          title: "Matter Goes Round",
          text: "Plants take up nutrients, animals eat plants and each other, and everything that dies becomes dead matter. Decomposers turn it back into nutrients. With no events, the total stays the same."
        },
        {
          id: "eco-energy",
          type: "info",
          title: "Energy Only Passes Through",
          text: "Sunlight comes in and heat goes out. The energy pyramid shows how little is passed up at each step, which is why there are fewer carnivores than plants."
        },
        {
          id: "eco-events",
          type: "info",
          title: "Cause a Disturbance",
          text: "Try the event buttons: a wildfire, a drought, fertilizer runoff, hunting the carnivores or adding herbivores. Dashed lines on the chart mark when each happened."
        },
        {
          id: "eco-cascade",
          type: "caution",
          title: "Everything Is Linked",
          text: "Remove one group and the others change too. Without carnivores, herbivores usually rise and plants then fall."
        },
        {
          id: "eco-limits",
          type: "caution",
          title: "A Simplified Model",
          text: "This model has three groups, one soil nutrient and no seasons. Real ecosystems have many species and many more links between them."
        }
      ]
    },

    "single-cell": {
      page_name: "single-cell",
      page_convo: [
        {
          id: "sc-intro",
          type: "info",
          title: "Life in a Dish",
          text: "Each disc is a single cell. Brown ones are hungry, green ones are well fed, and a white outline means a cell is about to divide. Click a cell to follow it."
        },
        {
          id: "sc-food",
          type: "info",
          title: "Finding Food",
          text: "Food appears as small dots. Cells with a sensing range steer toward the nearest particle; the others tumble at random. Raise the food supply to watch the population grow."
        },
        {
          id: "sc-energy",
          type: "info",
          title: "Energy Budget",
          text: "Swimming and resting both cost energy. Faster cells burn through their stores more quickly. Lower the resting energy use or raise the food supply if cells keep starving."
        },
        {
          id: "sc-divide",
          type: "info",
          title: "Growth and Division",
          text: "A cell grows as it feeds. A white outline means it is ready to divide. It splits into two cells that share its energy."
        },
        {
          id: "sc-death",
          type: "caution",
          title: "Starvation and Old Age",
          text: "A red ring marks a cell that starved and a grey ring marks one that died of old age. If food runs out, the population falls back."
        },
        {
          id: "sc-limits",
          type: "caution",
          title: "A Simplified Model",
          text: "In this model cells pass through each other and food appears at random. Real cells also change over generations, make waste and compete for space."
        }
      ]
    },

    "predator-prey": {
      page_name: "predator-prey",
      page_convo: [
        {
          id: "pp-intro",
          type: "info",
          title: "Predator\u2013Prey Populations",
          text: "The green line is the prey and the red line is the predators. Press Pause to freeze time, or Step to move forward a few months at a time."
        },
        {
          id: "pp-lag",
          type: "info",
          title: "Why the Cycles Happen",
          text: "When prey are plentiful, predators eat well and multiply. Then the prey fall, the predators starve, and the prey recover. Notice that the predator peak comes after the prey peak."
        },
        {
          id: "pp-food",
          type: "info",
          title: "Food Limit",
          text: "Lower the food limit for prey and the swings shrink until both populations settle at the balance point. Set it to no limit for endless cycles."
        },
        {
          id: "pp-phase",
          type: "info",
          title: "Phase Portrait",
          text: "The lower chart plots predators against prey. Each loop is one cycle. The white dot is the balance point where neither population would change."
        },
        {
          id: "pp-collapse",
          type: "caution",
          title: "Extinction",
          text: "If prey crash too far, fewer than one animal is left and the group dies out. Real populations are small and chance matters, so this happens in nature too."
        },
        {
          id: "pp-limits",
          type: "caution",
          title: "A Simplified Model",
          text: "This model has one prey, one predator and an even habitat. It shows the main idea of population cycles but leaves out disease, weather, hiding places and other species."
        }
      ]
    },


    "circuit-builder": {
      page_name: "circuit-builder",
      page_convo: [
        {
          id: "cb-intro",
          type: "info",
          title: "Circuit Builder",
          text: "Choose a tool from the toolbar, then click the canvas to place a component. Use Wire and click two terminals to connect them."
        },
        {
          id: "cb-presets",
          type: "info",
          title: "Start from a Preset",
          text: "The Series, Parallel and Mixed presets load ready-made circuits so you can see voltages and currents immediately."
        },
        {
          id: "cb-ohm",
          type: "info",
          title: "Ohm and Kirchhoff",
          text: "Current through a resistor is voltage divided by resistance. At every node the currents sum to zero; around every loop the voltages sum to zero."
        },
        {
          id: "cb-switch",
          type: "info",
          title: "Open and Close",
          text: "Click a switch on the canvas to open or close it. An open switch breaks the path and the current falls to zero."
        },
        {
          id: "cb-meters",
          type: "info",
          title: "Meters",
          text: "An ammeter sits in series and reports the current through its branch. A voltmeter spans two nodes and reports the potential difference."
        },
        {
          id: "cb-limits",
          type: "caution",
          title: "A Simplified Model",
          text: "This builder is ideal DC only: zero-resistance wires, ideal batteries and resistors, no capacitors, inductors or AC. That keeps the maths clear while you explore series and parallel networks."
        }
      ]
    },


    "truss-beam": {
      page_name: "truss-beam",
      page_convo: [
        {
          id: "tb-intro",
          type: "info",
          title: "Truss and Beam Loads",
          text: "Switch between Truss and Beam at the top. Load a preset to see forces immediately, or build your own structure with the tools."
        },
        {
          id: "tb-colour",
          type: "info",
          title: "Tension and Compression",
          text: "Blue members are in tension (pulling). Red members are in compression (pushing). Force values appear on each bar after analysis."
        },
        {
          id: "tb-supports",
          type: "info",
          title: "Supports",
          text: "A pin resists horizontal and vertical force. A roller resists vertical force only and allows horizontal movement."
        },
        {
          id: "tb-determinate",
          type: "caution",
          title: "Statically Determinate",
          text: "This solver needs m + r = 2j (members plus reaction components equal twice the joints). Too few supports or members and the structure is a mechanism; too many and it is indeterminate."
        },
        {
          id: "tb-beam",
          type: "info",
          title: "Beam Diagrams",
          text: "In Beam mode the diagrams under the span show shear force and bending moment. Add or remove point loads and watch both change."
        },
        {
          id: "tb-limits",
          type: "caution",
          title: "A Simplified Model",
          text: "Ideal pins, axial-only truss members, linear statics and no self-weight unless you add it as joint loads. There is no buckling check or material stress limit."
        }
      ]
    },


    "simple-machines": {
      page_name: "simple-machines",
      page_convo: [
        {
          id: "sm-intro",
          type: "info",
          title: "Simple Machines",
          text: "Choose Lever, Inclined plane, Pulley or Wheel and axle at the top. Sliders change the geometry and efficiency; the diagram and readouts update together."
        },
        {
          id: "sm-ma",
          type: "info",
          title: "Mechanical Advantage",
          text: "Ideal MA is load divided by ideal effort. Actual MA is lower when efficiency is less than 100 percent, so you must push harder than the ideal case."
        },
        {
          id: "sm-lever",
          type: "info",
          title: "Three Lever Classes",
          text: "Class 1 has the fulcrum in the middle. Class 2 has the load between fulcrum and effort. Class 3 has the effort between fulcrum and load and often has MA less than one."
        },
        {
          id: "sm-pulley",
          type: "info",
          title: "Counting Strands",
          text: "For an ideal pulley system the mechanical advantage equals the number of rope segments that support the load."
        },
        {
          id: "sm-limits",
          type: "caution",
          title: "A Simplified Model",
          text: "Machines are quasi-static and idealised. Friction is a single efficiency factor (or Coulomb mu on the plane). There is no inertia, cable stretch or compound machine diagram."
        }
      ]
    },


    "logic-gates": {
      page_name: "logic-gates",
      page_convo: [
        {
          id: "lg-intro",
          type: "info",
          title: "Logic Gates",
          text: "Place inputs, gates and outputs from the toolbar. Use Wire to connect an output port to an input port. Click an input switch to toggle between 0 and 1."
        },
        {
          id: "lg-colour",
          type: "info",
          title: "Green Means One",
          text: "Wires and ports drawn in green are logic 1. Grey means logic 0. Outputs update as soon as you change an input."
        },
        {
          id: "lg-half",
          type: "info",
          title: "Half Adder",
          text: "The Half adder preset shows Sum (XOR) and Carry (AND). Try every combination of the two inputs."
        },
        {
          id: "lg-nand",
          type: "info",
          title: "NAND Is Universal",
          text: "The XOR-from-NAND preset builds XOR with only NAND gates. NAND (or NOR) alone can implement any Boolean function."
        },
        {
          id: "lg-limits",
          type: "caution",
          title: "Combinational Only",
          text: "This lab has no clocks or memory. Loops are rejected. Real chips also have delay and voltage thresholds that are ignored here."
        }
      ]
    },


    "gear-trains": {
      page_name: "gear-trains",
      page_convo: [
        {
          id: "gt-intro",
          type: "info",
          title: "Gear Trains",
          text: "Choose Simple pair, Idler or Compound. Change tooth counts, input speed and torque. The gears animate at the resulting speeds."
        },
        {
          id: "gt-ratio",
          type: "info",
          title: "Speed and Teeth",
          text: "When two gears mesh, the speed ratio is the inverse of the tooth ratio. The larger gear turns more slowly."
        },
        {
          id: "gt-dir",
          type: "info",
          title: "Direction",
          text: "Each mesh reverses rotation. An idler adds a second reversal so the output turns the same way as the input."
        },
        {
          id: "gt-compound",
          type: "info",
          title: "Compound Trains",
          text: "Two gears fixed on one shaft multiply the stage ratios. That gives large reductions without a huge single gear."
        },
        {
          id: "gt-limits",
          type: "caution",
          title: "A Simplified Model",
          text: "Ideal spur gears only. Efficiency scales output torque; there is no backlash, tooth stress or helical geometry."
        }
      ]
    },


    "spring-mass-damper": {
      page_name: "spring-mass-damper",
      page_convo: [
        {
          id: "smd-intro",
          type: "info",
          title: "Spring-Mass-Damper",
          text: "The mass moves on a linear spring with viscous damping. The strip chart shows displacement versus time. Use presets to jump between regimes."
        },
        {
          id: "smd-zeta",
          type: "info",
          title: "Damping Ratio",
          text: "zeta less than 1 oscillates while decaying. zeta equal to 1 is critical. zeta greater than 1 returns slowly with no oscillation."
        },
        {
          id: "smd-wn",
          type: "info",
          title: "Natural Frequency",
          text: "omega_n equals the square root of k over m. It sets how fast the system wants to oscillate when damping is light."
        },
        {
          id: "smd-res",
          type: "caution",
          title: "Resonance",
          text: "When a harmonic force drives the mass near omega_n, amplitude grows large if damping is small. Try the Resonance preset."
        },
        {
          id: "smd-limits",
          type: "caution",
          title: "A Simplified Model",
          text: "Linear 1DOF only. No friction, no multi-mode structures, no geometric nonlinearity."
        }
      ]
    },


    "stress-strain": {
      page_name: "stress-strain",
      page_convo: [
        {
          id: "ss-intro",
          type: "info",
          title: "Stress and Strain",
          text: "A bar is fixed at one end and pulled by force F. Stress is F over area; strain is elongation over length. The plot shows where you sit on the elastic line."
        },
        {
          id: "ss-hooke",
          type: "info",
          title: "Hooke and Young",
          text: "In the linear range, stress equals E times strain. Elongation is FL over AE. Larger E means less stretch for the same load."
        },
        {
          id: "ss-safety",
          type: "caution",
          title: "Safety Factor",
          text: "n is yield stress divided by working stress. If n drops below 1, the ideal model says the bar has yielded."
        },
        {
          id: "ss-area",
          type: "info",
          title: "Area Matters",
          text: "Halving the diameter cuts area by four and multiplies stress by four. Diameter is a strong lever on safety."
        },
        {
          id: "ss-limits",
          type: "caution",
          title: "A Simplified Model",
          text: "Uniaxial, uniform bar only. No bending, buckling, stress concentrations or full plastic curve."
        }
      ]
    },


    "robot-arm": {
      page_name: "robot-arm",
      page_convo: [
        {
          id: "ra-intro",
          type: "info",
          title: "Robot Arm",
          text: "Two links, two revolute joints. Move the joint-angle sliders for forward kinematics, or click in the workspace for inverse kinematics."
        },
        {
          id: "ra-fk",
          type: "info",
          title: "Forward Kinematics",
          text: "Given theta1 and theta2, the end-effector position is unique. Watch x and y update as you turn the joints."
        },
        {
          id: "ra-ik",
          type: "info",
          title: "Inverse Kinematics",
          text: "Given a target point, there are usually two solutions: elbow up and elbow down. Switch the toggle to see both."
        },
        {
          id: "ra-ws",
          type: "info",
          title: "Workspace",
          text: "The shaded ring is every point the end-effector can reach. Outside the outer circle or inside the inner hole, IK fails."
        },
        {
          id: "ra-limits",
          type: "caution",
          title: "Kinematics Only",
          text: "No dynamics, gravity, joint limits or collisions. Orientation of the end-effector is not controlled."
        }
      ]
    },


    "fluid-dynamics": {
      page_name: "fluid-dynamics",
      page_convo: [
        {
          id: "fd-intro",
          type: "info",
          title: "Fluid Dynamics",
          text: "A venturi-style pipe: inlet and throat. Continuity sets the speeds from the diameters and flow rate; Bernoulli finds the pressures."
        },
        {
          id: "fd-cont",
          type: "info",
          title: "Continuity",
          text: "A1 v1 equals A2 v2 for incompressible flow. Halve the diameter and speed rises by about four."
        },
        {
          id: "fd-bern",
          type: "info",
          title: "Bernoulli",
          text: "Along a streamline, pressure head, velocity head and elevation head trade off. Faster flow usually means lower pressure."
        },
        {
          id: "fd-loss",
          type: "caution",
          title: "Head Loss",
          text: "When the friction factor f is greater than zero, total head falls between stations. Ideal Bernoulli has f equal to zero."
        },
        {
          id: "fd-limits",
          type: "caution",
          title: "A Simplified Model",
          text: "Steady 1D incompressible liquid only. No compressibility, free-surface waves or full Moody-chart friction."
        }
      ]
    },


    "heat-transfer": {
      page_name: "heat-transfer",
      page_convo: [
        {
          id: "ht-intro",
          type: "info",
          title: "Heat Transfer",
          text: "A multilayer plane wall between hot and cold sides. Each layer is a thermal resistance. Heat flux is the overall temperature drop divided by total resistance."
        },
        {
          id: "ht-r",
          type: "info",
          title: "Resistance",
          text: "Conduction resistance is thickness over conductivity. Convection resistance is one over the heat-transfer coefficient h."
        },
        {
          id: "ht-ins",
          type: "info",
          title: "Insulation",
          text: "Low-k materials dominate the total R. Adding insulation is the usual way to cut heat loss through a wall."
        },
        {
          id: "ht-profile",
          type: "info",
          title: "Temperature Profile",
          text: "The T(x) plot is piecewise linear in each layer. Steeper slopes appear where conductivity is lower."
        },
        {
          id: "ht-limits",
          type: "caution",
          title: "A Simplified Model",
          text: "Steady one-dimensional conduction with constant k. No radiation networks, no transients, no 2D edge effects."
        }
      ]
    },


    "fluid-mechanics": {
      page_name: "fluid-mechanics",
      page_convo: [
        {
          id: "fm-intro",
          type: "info",
          title: "Fluid Mechanics",
          text: "Three modes: Hydrostatics (pressure vs depth), Manometer (pressure from column height), and Buoyancy (Archimedes)."
        },
        {
          id: "fm-p",
          type: "info",
          title: "Hydrostatics",
          text: "Gauge pressure is rho g h. Absolute pressure adds atmospheric pressure. Denser fluids produce larger pressure at the same depth."
        },
        {
          id: "fm-mano",
          type: "info",
          title: "Manometer",
          text: "A U-tube converts a pressure difference into a measurable height difference. Mercury is common because rho is large."
        },
        {
          id: "fm-buoy",
          type: "info",
          title: "Buoyancy",
          text: "The buoyant force equals the weight of the fluid displaced. An object floats when that force can match its weight."
        },
        {
          id: "fm-limits",
          type: "caution",
          title: "Statics Only",
          text: "No flowing fluid here. For Bernoulli and venturi flow, use the Fluid Dynamics lab."
        }
      ]
    },


    "reaction-rates": {
      page_name: "reaction-rates",
      page_convo: [
        {
          id: "rr-intro",
          type: "info",
          title: "Reaction Rates",
          text: "Pick zero, first or second order. The graph shows how reactant concentration falls with time. Half-life is marked with a dashed line."
        },
        {
          id: "rr-order",
          type: "info",
          title: "Order Shapes",
          text: "Zero-order is a straight line down. First-order is exponential. Second-order falls quickly at first, then slows."
        },
        {
          id: "rr-hl",
          type: "info",
          title: "Half-Life",
          text: "For first-order reactions t half is constant and independent of starting concentration. For second-order it depends on [A]0."
        },
        {
          id: "rr-arr",
          type: "info",
          title: "Arrhenius",
          text: "Enable Arrhenius to let temperature and activation energy set k. Higher T or lower Ea means a faster reaction."
        },
        {
          id: "rr-limits",
          type: "caution",
          title: "A Simplified Model",
          text: "Single irreversible reactant only. No reversible equilibrium or multi-step mechanisms in this lab."
        }
      ]
    },


    "chemical-equilibrium": {
      page_name: "chemical-equilibrium",
      page_convo: [
        {
          id: "eq-intro",
          type: "info",
          title: "Chemical Equilibrium",
          text: "Pick a reaction. Grey bars are initial concentrations; coloured bars are equilibrium. The ICE table updates with every change."
        },
        {
          id: "eq-kc",
          type: "info",
          title: "Kc and Q",
          text: "Kc is fixed for a given temperature. Q is computed from the initial concentrations. At equilibrium Q equals Kc."
        },
        {
          id: "eq-le",
          type: "info",
          title: "Le Chatelier",
          text: "Add product, change volume or shift Kc. The system moves to partially counteract the change."
        },
        {
          id: "eq-haber",
          type: "info",
          title: "Haber Volume",
          text: "On the Haber reaction, compressing the volume favours ammonia because the product side has fewer gas moles."
        },
        {
          id: "eq-limits",
          type: "caution",
          title: "Ideal Equilibrium",
          text: "Concentrations are ideal. Equilibrium is solved instantly — there is no kinetic approach curve in this lab."
        }
      ]
    },


    "buffers": {
      page_name: "buffers",
      page_convo: [
        {
          id: "buf-intro",
          type: "info",
          title: "Acid-Base and Buffers",
          text: "Three modes: Weak acid, Buffer and Strong acid/base. The dial shows pH; the colour bar runs from acidic to basic."
        },
        {
          id: "buf-weak",
          type: "info",
          title: "Weak Acids",
          text: "A weak acid only partly dissociates. The quadratic solution for [H+] uses Ka and the analytical concentration."
        },
        {
          id: "buf-hh",
          type: "info",
          title: "Henderson-Hasselbalch",
          text: "In a buffer, pH is approximately pKa plus log of [A-]/[HA]. Equal amounts give pH near pKa."
        },
        {
          id: "buf-cap",
          type: "caution",
          title: "Buffer Capacity",
          text: "Add strong acid or base to stress the buffer. When you exceed the available HA or A-, capacity is lost and pH swings."
        },
        {
          id: "buf-limits",
          type: "caution",
          title: "Ideal Solutions",
          text: "Dilute aqueous ideal solutions at about 25 C. No activity coefficients or polyprotic acids beyond a single Ka."
        }
      ]
    },


    "electrochemistry": {
      page_name: "electrochemistry",
      page_convo: [
        {
          id: "ec-intro",
          type: "info",
          title: "Galvanic Cell",
          text: "Two half-cells share a salt bridge and an external wire. The electrode with the higher reduction potential is the cathode."
        },
        {
          id: "ec-e0",
          type: "info",
          title: "Standard Potential",
          text: "E degree cell equals E degree cathode minus E degree anode. For Daniell (Zn-Cu) that is about 1.10 V at standard conditions."
        },
        {
          id: "ec-nernst",
          type: "info",
          title: "Nernst Equation",
          text: "At non-standard concentrations, E equals E degree minus (0.05916/n) log Q. Raising product ions or lowering reactant ions reduces E."
        },
        {
          id: "ec-dg",
          type: "info",
          title: "Free Energy",
          text: "Delta G equals minus n F E. A positive cell potential means a spontaneous reaction and a negative free-energy change."
        },
        {
          id: "ec-flow",
          type: "info",
          title: "Electron Flow",
          text: "Electrons travel in the wire from anode to cathode. The salt bridge moves ions to keep each half-cell electrically neutral."
        },
        {
          id: "ec-limits",
          type: "caution",
          title: "Ideal Cells",
          text: "No overpotential, internal resistance or kinetic limits. Activities are approximated by molar concentrations at 25 C."
        }
      ]
    },


    "calorimetry": {
      page_name: "calorimetry",
      page_convo: [
        {
          id: "cal-intro",
          type: "info",
          title: "Calorimetry",
          text: "Four modes: specific heat of a metal, enthalpy of solution, neutralisation and bomb combustion. The thermometer tracks the final temperature."
        },
        {
          id: "cal-metal",
          type: "info",
          title: "Specific Heat",
          text: "Hot metal in cool water. Heat lost by the metal equals heat gained by the water (and calorimeter). Solve for c or for T final."
        },
        {
          id: "cal-sol",
          type: "info",
          title: "Solution Enthalpy",
          text: "Exothermic salts warm the cup; endothermic salts cool it. Delta H soln is recovered from q and moles dissolved."
        },
        {
          id: "cal-neut",
          type: "info",
          title: "Neutralisation",
          text: "Strong acid plus strong base. The heat is referenced to moles of water formed from the limiting reactant."
        },
        {
          id: "cal-bomb",
          type: "info",
          title: "Bomb Calorimeter",
          text: "Constant-volume combustion. q_v gives Delta U. Delta H is approximately Delta U plus Delta n gas times RT."
        },
        {
          id: "cal-limits",
          type: "caution",
          title: "Ideal Calorimeter",
          text: "Adiabatic, instantaneous equilibrium. No heat leaks or cooling-curve corrections in this teaching model."
        }
      ]
    },


    "ideal-real-gases": {
      page_name: "ideal-real-gases",
      page_convo: [
        {
          id: "irg-intro",
          type: "info",
          title: "Ideal vs Real Gases",
          text: "Blue isotherm is the ideal gas law. Red is van der Waals. The lower chart shows compressibility Z; the green dashed line is Z = 1."
        },
        {
          id: "irg-ab",
          type: "info",
          title: "a and b",
          text: "Parameter a captures attractions and lowers pressure. Parameter b is excluded volume and raises pressure at high density."
        },
        {
          id: "irg-z",
          type: "info",
          title: "Compressibility",
          text: "Z less than 1 means attractions dominate. Z greater than 1 means finite molecular size dominates. Ideal gases always have Z = 1."
        },
        {
          id: "irg-crit",
          type: "info",
          title: "Critical Point",
          text: "From a and b you get Tc, Pc and Vc. At the critical isotherm the van der Waals curve has a horizontal inflection."
        },
        {
          id: "irg-limits",
          type: "caution",
          title: "van der Waals Limits",
          text: "Isotherm loops in the two-phase region are shown without a Maxwell construction. Real fluids need more accurate equations of state."
        }
      ]
    },


    "thermochemistry": {
      page_name: "thermochemistry",
      page_convo: [
        {
          id: "th-intro",
          type: "info",
          title: "Thermochemistry",
          text: "Three modes: formation enthalpies, Hess's law cycles and bond-enthalpy estimates. All energies are in kJ/mol at standard state."
        },
        {
          id: "th-form",
          type: "info",
          title: "Formation Enthalpies",
          text: "Delta H rxn equals the sum of nu times Delta H f of products minus the same for reactants. Elements in their standard states contribute zero."
        },
        {
          id: "th-hess",
          type: "info",
          title: "Hess's Law",
          text: "Scale, reverse or omit steps so the net stoichiometry matches the target. The summed Delta H is then the target enthalpy change."
        },
        {
          id: "th-bond",
          type: "info",
          title: "Bond Enthalpies",
          text: "Estimate Delta H as bonds broken minus bonds formed using average bond energies. Useful for gas-phase reactions but approximate."
        },
        {
          id: "th-limits",
          type: "caution",
          title: "Standard Values",
          text: "Tables are at 298 K. No Kirchhoff temperature corrections. Bond averages ignore molecular environment and phase changes."
        }
      ]
    },


    "chemical-reactions": {
      page_name: "chemical-reactions",
      page_convo: [
        {
          id: "cr-intro",
          type: "info",
          title: "Chemical Reactions",
          text: "Select elements on the periodic table (up to three). Known combinations show a balanced equation, product name and reaction type."
        },
        {
          id: "cr-nh3",
          type: "info",
          title: "Stoichiometry",
          text: "N plus H gives ammonia NH3, written N2 + 3H2 → 2NH3. The product is not NH2 — valence and balancing set the formula."
        },
        {
          id: "cr-types",
          type: "info",
          title: "Reaction Types",
          text: "Synthesis, oxidation and halogenation appear for common element pairs. Conditions are noted when they matter."
        },
        {
          id: "cr-none",
          type: "caution",
          title: "No Simple Product",
          text: "Noble gases and many pairs do not form ordinary compounds under mild conditions. The lab says so instead of inventing a formula."
        },
        {
          id: "cr-limits",
          type: "caution",
          title: "Curated Knowledge",
          text: "This is a teaching reaction table for main-group binaries, not a full prediction engine for every element combination."
        }
      ]
    },

    mathematics: labPage("mathematics", "Mathematics", "equations, statistics, geometry and abstract ideas"),
    engineering: {
      page_name: "engineering",
      page_convo: [
        {
          id: "engineering-welcome",
          type: "info",
          title: "Engineering Laboratory",
          text: "This is the Engineering hub. Eleven engineering projects are available, including Fluid Mechanics for hydrostatics and buoyancy."
        },
        {
          id: "engineering-more",
          type: "caution",
          title: "More Projects Planned",
          text: "Mechanisms and control systems are on the roadmap. Projects that are not yet built appear as planned cards."
        }
      ]
    },

    "coming-soon": {
      page_name: "coming-soon",
      page_convo: [
        {
          id: "soon-info",
          type: "info",
          title: "More Laboratories Coming",
          text: "New virtual laboratories and interactive experiments will appear here as the platform grows."
        }
      ]
    },

    // ------------------------------------------------------------------
    // BioCell Sim pages (optional module – used when the BioCell
    // simulator is hosted inside the Biology laboratory)
    // ------------------------------------------------------------------
  // ------------------------------------------------------------------
  // Lab / Simulator (index.html)
  // ------------------------------------------------------------------
  lab: {
    page_name: "lab",
    page_convo: [
      {
        id: "lab-ready",
        type: "info",
        title: "Laboratory Ready",
        text: "You are now in the simulation laboratory. Configure the medium and cell types from the start menu, then use Play, Step, and the control panel to observe and influence the culture."
      },
      {
        id: "lab-camera",
        type: "info",
        title: "Camera & Possession",
        text: "You can zoom with the mouse wheel or the on-screen controls. Right-click or double-click a cell to possess it and follow its individual statistics until it dies or you release it."
      },
      {
        id: "lab-stress",
        type: "caution",
        title: "Environmental Stress",
        text: "Temperature, pH, viscosity, and oxygen all affect metabolism and movement. Extreme values will slow growth or cause population decline. Monitor the header statistics and the charts."
      },
      {
        id: "lab-collapse",
        type: "warning",
        title: "Population Collapse",
        text: "If average energy falls sharply or cell count drops rapidly, add food or restore milder media conditions. A culture can collapse permanently if conditions remain hostile."
      }
    ]
  },

  // ------------------------------------------------------------------
  // Tutorial (future page)
  // ------------------------------------------------------------------
  tutorial: {
    page_name: "tutorial",
    page_convo: [
      {
        id: "tutorial-intro",
        type: "info",
        title: "Guided Introduction",
        text: "This tutorial walks you through the core concepts of single-celled life and the mechanics of the simulator. Proceed step by step; I will highlight the most important points."
      },
      {
        id: "tutorial-fission",
        type: "info",
        title: "Binary Fission",
        text: "When a cell accumulates enough energy and size, it divides into two daughter cells. This is the primary way populations grow in BioCell Sim."
      },
      {
        id: "tutorial-chemotaxis",
        type: "info",
        title: "Chemotaxis",
        text: "Cells sense local nutrient gradients and bias their movement toward higher concentrations. You will see them cluster around food patches over time."
      }
    ]
  },

  // ------------------------------------------------------------------
  // Exam (future page)
  // ------------------------------------------------------------------
  exam: {
    page_name: "exam",
    page_convo: [
      {
        id: "exam-mode",
        type: "info",
        title: "Assessment Mode",
        text: "You are entering an assessed exercise. Read each question carefully. I will remain available for general guidance, but I will not provide direct answers."
      },
      {
        id: "exam-time",
        type: "caution",
        title: "Time & Integrity",
        text: "Manage your time. Submitting incomplete work or leaving the assessment early may affect your recorded result."
      },
      {
        id: "exam-irreversible",
        type: "warning",
        title: "Irreversible Actions",
        text: "Some exam actions cannot be undone. Confirm your choices before proceeding when the interface asks you to do so."
      }
    ]
  }
  };

  global.JENNY_TEXTS = JENNY_TEXTS;
})(typeof window !== "undefined" ? window : this);
