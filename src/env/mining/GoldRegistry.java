package mining;

import cartago.Artifact;
import cartago.OPERATION;
import cartago.OpFeedbackParam;

/**
 * Shared blackboard where miners reserve gold pieces so partners of the same
 * team do not pursue the same target.
 *
 * Reservation is INTRA-team: reserving fails only if the SAME team already
 * reserved that piece (partners must not collide). The other team can still
 * reserve/pursue the same piece, so the two teams keep racing for gold.
 *
 * Each reservation is exposed as an observable property reserved(X,Y,Team),
 * so focusing agents can filter it out of their choices.
 */
public class GoldRegistry extends Artifact {

    void init() {
        // no reservations at start
    }

    /** Reserve gold (X,Y) for Team. ok=true if granted, false if the same
     *  team had already reserved it. */
    @OPERATION
    void reserve(int x, int y, String team, OpFeedbackParam<Boolean> ok) {
        if (hasObsPropertyByTemplate("reserved", x, y, team)) {
            ok.set(false);
        } else {
            defineObsProperty("reserved", x, y, team);
            ok.set(true);
        }
    }

    /** Release this team's reservation on gold (X,Y), if any. */
    @OPERATION
    void release(int x, int y, String team) {
        if (hasObsPropertyByTemplate("reserved", x, y, team)) {
            removeObsPropertyByTemplate("reserved", x, y, team);
        }
    }
}
