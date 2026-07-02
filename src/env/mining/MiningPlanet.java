package mining;

import jason.asSyntax.Atom;
import jason.asSyntax.Term;
import jason.environment.grid.Location;

import java.util.logging.Logger;

import cartago.Artifact;
import cartago.OPERATION;
import cartago.ObsProperty;

public class MiningPlanet extends Artifact {

    private static Logger logger = Logger.getLogger(MiningPlanet.class.getName());

    static WorldModel  model = null;
    static WorldView   view;

    static int     simId    = 5; // type of environment
    static int     sleep    = 0;   // 0 = max speed (no delay between actions)
    static boolean hasGUI   = true;
    static boolean ended    = false; // true once all gold has been collected

    int     agId     = -1;

    public enum Move {
        UP, DOWN, RIGHT, LEFT
    };

    @OPERATION
    public void init(int scenario, int agId) {
        this.agId = agId;
        initWorld(scenario);
    }

    public int getSimId() {
        return simId;
    }

    public void setSleep(int s) {
        sleep = s;
    }

    @OPERATION void up() throws Exception {     move(Move.UP);    }
    @OPERATION void down() throws Exception {   move(Move.DOWN);  }
    @OPERATION void right() throws Exception {  move(Move.RIGHT); }
    @OPERATION void left() throws Exception {   move(Move.LEFT);  }
    void move(Move m) throws Exception {
        if (sleep > 0) await_time(sleep);
        model.move(m, agId);
        updateAgPercept();
    }

    @OPERATION void pick() throws Exception {
        if (sleep > 0) await_time(sleep);
        model.pick(agId);
        updateAgPercept();
    }
    @OPERATION void drop() throws Exception {
        if (sleep > 0) await_time(sleep);
        model.drop(agId);
        view.udpateCollectedGolds();
        updateAgPercept();
    }
    @OPERATION void skip() {
        if (sleep > 0) await_time(sleep);
        updateAgPercept();
    }

    public synchronized void initWorld(int w) {
        simId = w;
        ended = false;
        try {
            if (model == null) {
                switch (w) {
                case 1: model = WorldModel.world1(); break;
                case 2: model = WorldModel.world2(); break;
                case 3: model = WorldModel.world3(); break;
                case 4: model = WorldModel.world4(); break;
                case 5: model = WorldModel.world5(); break;
                case 6: model = WorldModel.world6(); break;
                default:
                    logger.info("Invalid index!");
                    return;
                }
                if (hasGUI) {
                    view = new WorldView(model);
                    view.setEnv(this);
                    view.udpateCollectedGolds();
                }
            }
            defineObsProperty("gsize", simId, model.getWidth(), model.getHeight());
            defineObsProperty("depot", simId, model.getDepot().x, model.getDepot().y);
            defineObsProperty("pos", -1, -1);
            updateAgPercept();
            //informAgsEnvironmentChanged();
        } catch (Exception e) {
            logger.warning("Error creating world "+e);
            e.printStackTrace();
        }
    }

    public void endSimulation() {
        defineObsProperty("end_of_simulation", simId, 0);
        //informAgsEnvironmentChanged();
        if (view != null) view.setVisible(false);
        WorldModel.destroy();
    }

    private void updateAgPercept() {
        // its location
        Location l = model.getAgPos(agId);
        ObsProperty p = getObsProperty("pos");
        p.updateValue(0, l.x);
        p.updateValue(1, l.y);

        if (model.isCarryingGold(agId)) {
            if (!hasObsProperty("carrying_gold"))
                defineObsProperty("carrying_gold");
        } else try {
            removeObsProperty("carrying_gold");
        } catch (IllegalArgumentException e) {}

        // what's around
        updateAgPercept(l.x - 1, l.y - 1);
        updateAgPercept(l.x - 1, l.y);
        updateAgPercept(l.x - 1, l.y + 1);
        updateAgPercept(l.x, l.y - 1);
        updateAgPercept(l.x, l.y);
        updateAgPercept(l.x, l.y + 1);
        updateAgPercept(l.x + 1, l.y - 1);
        updateAgPercept(l.x + 1, l.y);
        updateAgPercept(l.x + 1, l.y + 1);

        checkEndGame();

        //view.update();
    }

    /**
     * End the game once every piece of gold has been delivered. Runs after each
     * agent action, so each agent perceives the end within one step of its own.
     * The end is exposed as an observable property on THIS agent's artifact
     * (each miner focuses its own MiningPlanet), and a single GAME OVER line
     * with the final team scores is logged the first time it is detected.
     */
    private void checkEndGame() {
        if (model == null || model.getInitialNbGolds() <= 0) return;
        if (!model.isAllGoldsCollected()) return;

        if (!hasObsProperty("end_of_simulation")) {
            defineObsProperty("end_of_simulation", simId, 0);
        }
        synchronized (MiningPlanet.class) {
            if (!ended) {
                ended = true;
                int a = model.getGoldsTeamA();
                int b = model.getGoldsTeamB();
                String winner = (a > b) ? "Team A" : (b > a) ? "Team B" : "Tie";
                logger.info("=== GAME OVER: all " + model.getInitialNbGolds()
                    + " gold collected. Team A=" + a + " Team B=" + b
                    + " -> winner: " + winner + " ===");
                if (view != null) view.udpateCollectedGolds();
            }
        }
    }

    private static Term gold     = new Atom("gold");
    private static Term obstacle = new Atom("obstacle");

    private void updateAgPercept(int x, int y) {
        if (model == null || !model.inGrid(x,y)) return;

        // remove all first
        try {
            removeObsPropertyByTemplate("cell", null, null, null);
        } catch (IllegalArgumentException e) {}

        if (model.hasObject(WorldModel.OBSTACLE, x, y)) {
            defineObsProperty("cell", x, y, obstacle);
        } else if (model.hasObject(WorldModel.GOLD, x, y)) {
            defineObsProperty("cell", x, y, gold);
        }

        //if (model.hasObject(WorldModel.ENEMY, x, y))
        //    defineObsProperty("cell", x, y, "enemy");
        //if (model.hasObject(WorldModel.AGENT, x, y))
        //    defineObsProperty("cell", x, y, "ally");
    }

}
