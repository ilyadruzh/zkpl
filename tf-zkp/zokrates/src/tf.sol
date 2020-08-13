pragma solidity ^0.4.26;

contract Admined {
    event AdminAdded(address indexed admin, address indexed batya);
    event AdminRemoved(address indexed admin, address indexed batya);

    bytes32 public constant VERSION = "0.0.0";
    address public predecessor;
    address public successor;
    address[] public admins;

    constructor(address pred) public {
        predecessor = pred;
        admins = [msg.sender];

        emit AdminAdded(msg.sender, msg.sender);
    }

    function suspendPredecessor() external onlybatya {
        Admined(predecessor).setSuccessor(this);
    }

    function setSuccessor(address s) external onlybatya {
        successor = s;
    }

    function setPredecessor(address p) external onlybatya {
        predecessor = p;
    }

    function addAdmin(address a) external onlybatya {
        require(!isAdmin(a), "duplicated admin");

        admins.push(a);

        emit AdminAdded(a, msg.sender);
    }

    function removeAdmin(address a) external onlybatya {
        require(admins.length > 1, "be careful");

        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] != a) {
                continue;
            }

            uint256 last = admins.length - 1;
            admins[i] = admins[last];
            admins.length--;

            emit AdminRemoved(a, msg.sender);
        }
    }

    function isAdmin(address a) public view returns (bool) {
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] == a) {
                return true;
            }
        }
        return false;
    }

    function allAdmins() external view returns (address[]) {
        return admins;
    }

    modifier onlybatya {
        require(isAdmin(msg.sender), "admin required");
        _;
    }
}

contract Orgs is Admined {
    event OrgAdded(bytes32 indexed org, address indexed admin);
    event OrgSuspended(
        bytes32 indexed org,
        bool indexed suspended,
        address indexed admin
    );

    event RobotAdded(
        bytes32 indexed org,
        address indexed robot,
        address indexed admin
    );
    event RobotRemoved(
        bytes32 indexed org,
        address indexed robot,
        address indexed admin
    );

    event OperatorAdded(
        bytes32 indexed org,
        bytes32 indexed operator,
        address indexed admin
    );
    event OperatorSuspended(
        bytes32 indexed org,
        bytes32 indexed operator,
        bool susp,
        address indexed admin
    );
    event OperatorKeyAdded(
        bytes32 indexed org,
        bytes32 indexed operator,
        address key,
        address indexed admin
    );
    event OperatorKeyRemoved(
        bytes32 indexed org,
        bytes32 indexed operator,
        address key,
        address indexed admin
    );

    struct User {
        bytes32 id;
        bytes32 org;
        address[] keys;
        mapping(bytes32 => bytes32) meta;
    }

    struct Org {
        bytes32 id;
        address[] robots;
        bytes32[] operators;
        mapping(bytes32 => bytes32) meta;
    }

    mapping(bytes32 => Org) public orgs;
    mapping(address => bytes32) public orgsByRobot;
    bytes32[] public orgsList;

    mapping(bytes32 => User) public users;
    mapping(address => bytes32) public usersByKey;

    mapping(address => bytes) public certs;

    function addOrg(bytes32 org) external onlybatya {
        require(org != "", "empty org id");
        require(org != "public", "public is keyword");
        require(orgs[org].id == "", "duplicated org");

        Org memory o = Org({
            id: org,
            robots: new address[](0),
            operators: new bytes32[](0)
        });

        orgs[org] = o;
        orgsList.push(org);

        emit OrgAdded(org, msg.sender);
    }

    function suspendOrg(bytes32 org, bool susp) external onlybatya {
        Org storage o = orgs[org];

        require(o.id == org, "no such org");
        require((o.meta["suspended"] != 0) != susp, "already in that state");

        if (susp) {
            o.meta["suspended"] = "true";
        } else {
            delete o.meta["suspended"];
        }

        emit OrgSuspended(org, susp, msg.sender);
    }

    function addChildOrg(bytes32 parent, bytes32 org)
        external
        checkorg(parent)
    {
        require(org != "", "empty org id");
        require(org != "public", "public is keyword");
        require(orgs[org].id == "", "duplicated org");

        Org memory o = Org({
            id: org,
            robots: new address[](0),
            operators: new bytes32[](0)
        });

        orgs[org] = o;
        orgsList.push(org);

        orgs[org].meta["parent"] = parent;

        emit OrgAdded(org, msg.sender);
    }

    function suspendChildOrg(
        bytes32 parent,
        bytes32 org,
        bool susp
    ) external checkorg(parent) {
        Org storage o = orgs[org];

        require(o.id == org, "no such org");
        require(o.meta["parent"] == parent, "not a child org");
        require((o.meta["suspended"] != 0) != susp, "already in that state");

        if (susp) {
            o.meta["suspended"] = "true";
        } else {
            delete o.meta["suspended"];
        }

        emit OrgSuspended(org, susp, msg.sender);
    }

    function addRobot(
        bytes32 org,
        address r,
        bytes cert
    ) external checkorg(org) {
        Org storage o = orgs[org];

        require(orgsByRobot[r] == "", "duplicated robot");

        o.robots.push(r);
        orgsByRobot[r] = org;
        certs[r] = cert;

        emit RobotAdded(org, r, msg.sender);
    }

    function removeRobot(bytes32 org, address r) external checkorg(org) {
        Org storage o = orgs[org];

        require(isRobot(org, r), "no such robot");

        for (uint256 i = 0; i < o.robots.length; i++) {
            if (o.robots[i] != r) {
                continue;
            }

            uint256 last = o.robots.length - 1;
            o.robots[i] = o.robots[last];
            o.robots.length--;

            break;
        }

        delete orgsByRobot[r];

        emit RobotRemoved(org, r, msg.sender);
    }

    function addUser(
        bytes32 org,
        bytes32 id,
        address key,
        bytes cert
    ) external checkorg(org) {
        Org storage o = orgs[org];

        require(users[id].id == "", "duplicated user");
        require(usersByKey[key] == "", "duplicated key");

        User memory u = User({id: id, org: org, keys: new address[](1)});
        u.keys[0] = key;

        users[id] = u;
        o.operators.push(id);
        usersByKey[key] = id;
        certs[key] = cert;

        emit OperatorAdded(org, id, msg.sender);
        emit OperatorKeyAdded(org, id, key, msg.sender);
    }

    function addUserKey(
        bytes32 org,
        bytes32 id,
        address key,
        bytes cert
    ) external checkorg(org) {
        User storage u = users[id];

        require(u.id == id, "no such user");
        require(u.org == org, "bad org");
        require(usersByKey[key] == "", "duplicated key");

        u.keys.push(key);
        usersByKey[key] = id;
        certs[key] = cert;

        emit OperatorKeyAdded(org, id, key, msg.sender);
    }

    function removeUserKey(
        bytes32 org,
        bytes32 id,
        address key
    ) external checkorg(org) {
        User storage u = users[id];

        require(u.id == id, "no such user");
        require(u.org == org, "bad org");
        require(usersByKey[key] == id, "no such key");

        for (uint256 i = 0; i < u.keys.length; i++) {
            if (u.keys[i] != key) {
                continue;
            }

            uint256 last = u.keys.length - 1;
            u.keys[i] = u.keys[last];
            u.keys.length--;

            break;
        }

        delete usersByKey[key];

        emit OperatorKeyRemoved(org, id, key, msg.sender);
    }

    function suspendUser(
        bytes32 org,
        bytes32 id,
        bool susp
    ) external checkorg(org) {
        User storage u = users[id];

        require(u.org == org, "no such user");
        require((u.meta["suspended"] != 0) != susp, "already in that state");

        if (susp) {
            u.meta["suspended"] = "true";
        } else {
            delete u.meta["suspended"];
        }

        emit OperatorSuspended(org, id, susp, msg.sender);
    }

    function isRobot(bytes32 org, address a) public view returns (bool) {
        Org storage o = orgs[org];

        for (uint256 i = 0; i < o.robots.length; i++) {
            if (o.robots[i] == a) {
                return true;
            }
        }

        return false;
    }

    function isParentRobot(bytes32 org, address a) public view returns (bool) {
        while (org != "") {
            if (isRobot(org, a)) {
                return true;
            }

            org = orgs[org].meta["parent"];
        }

        return false;
    }

    function isOperator(bytes32 org, bytes32 id) public view returns (bool) {
        User storage u = users[id];

        return u.org == org;
    }

    function isOperatorKey(bytes32 org, address key)
        public
        view
        returns (bool)
    {
        User storage u = users[usersByKey[key]];

        return u.org == org;
    }

    function setOrgMeta(
        bytes32 org,
        bytes32 k,
        bytes32 v
    ) public checkorg(org) {
        Org storage o = orgs[org];
        o.meta[k] = v;
    }

    function setOrgMetaMany(
        bytes32 org,
        bytes32[] ks,
        bytes32[] vs
    ) public checkorg(org) {
        Org storage o = orgs[org];

        require(ks.length == vs.length, "bad args");

        for (uint256 i = 0; i < vs.length; i++) {
            o.meta[ks[i]] = vs[i];
        }
    }

    function casOrgMeta(
        bytes32 org,
        bytes32 k,
        bytes32 old,
        bytes32 v
    ) public checkorg(org) {
        Org storage o = orgs[org];

        require(o.meta[k] == old, "cas failed");

        o.meta[k] = v;
    }

    function orgMeta(bytes32 org, bytes32 k) public view returns (bytes32) {
        Org storage o = orgs[org];

        require(o.id == org, "no such org");

        return o.meta[k];
    }

    function orgMetaMany(bytes32 org, bytes32[] ks)
        public
        view
        returns (bytes32[])
    {
        Org storage o = orgs[org];

        require(o.id == org, "no such org");

        bytes32[] memory res = new bytes32[](ks.length);
        for (uint256 i = 0; i < ks.length; i++) {
            res[i] = o.meta[ks[i]];
        }

        return res;
    }

    function setUserMeta(
        bytes32 id,
        bytes32 k,
        bytes32 v
    ) public checkuserid(id) {
        User storage u = users[id];
        u.meta[k] = v;
    }

    function setUserMetaMany(
        bytes32 id,
        bytes32[] ks,
        bytes32[] vs
    ) public checkuserid(id) {
        User storage u = users[id];

        require(ks.length == vs.length, "bad args");

        for (uint256 i = 0; i < vs.length; i++) {
            u.meta[ks[i]] = vs[i];
        }
    }

    function casUserMeta(
        bytes32 id,
        bytes32 k,
        bytes32 old,
        bytes32 v
    ) public checkuserid(id) {
        User storage u = users[id];

        require(u.meta[k] == old, "cas failed");

        u.meta[k] = v;
    }

    function userKeys(bytes32 id) external view returns (address[]) {
        User storage u = users[id];

        require(u.id == id, "no such user");

        return u.keys;
    }

    function userMeta(bytes32 id, bytes32 k) public view returns (bytes32) {
        User storage u = users[id];

        require(u.id == id, "no such user");

        return u.meta[k];
    }

    function userMetaMany(bytes32 id, bytes32[] ks)
        public
        view
        returns (bytes32[])
    {
        User storage u = users[id];

        require(u.id == id, "no such user");

        bytes32[] memory res = new bytes32[](ks.length);
        for (uint256 i = 0; i < ks.length; i++) {
            res[i] = u.meta[ks[i]];
        }

        return res;
    }

    function orgRobots(bytes32 org) external view returns (address[]) {
        Org storage o = orgs[org];

        require(o.id == org, "no such org");

        return o.robots;
    }

    function orgOperators(bytes32 org) external view returns (bytes32[]) {
        Org storage o = orgs[org];

        require(o.id == org, "no such org");

        return o.operators;
    }

    function orgRobotsOperators(bytes32 org)
        external
        view
        returns (address[], bytes32[])
    {
        Org storage o = orgs[org];

        require(o.id == org, "no such org");

        return (o.robots, o.operators);
    }

    function userCanLogin(address robot, address addr)
        external
        view
        returns (
            bool,
            bytes32,
            bytes32
        )
    {
        User storage u = users[usersByKey[addr]];

        if (u.id == "") {
            return (false, "", "no such user");
        }

        if (u.meta["suspended"] != 0) {
            return (false, u.org, "user suspended");
        }

        bytes32 org = u.org;

        while (org != "") {
            Org storage o = orgs[org];

            if (o.meta["suspended"] != 0) {
                return (false, o.id, "org suspended");
            }

            if (isRobot(o.id, robot)) {
                if (org == u.org) {
                    return (true, o.id, "ok");
                } else {
                    return (true, o.id, "parent org");
                }
            }

            org = o.meta["parent"];
        }

        return (false, u.org, "bad org");
    }

    function orgsPage(uint32 n, uint32 start)
        public
        view
        returns (
            bytes32[],
            bytes32[],
            uint32
        )
    {
        if (start >= orgsList.length) {
            return (res, prof, 0);
        }
        if (start + n > orgsList.length) {
            n = uint32(orgsList.length) - start;
        }

        bytes32[] memory res = new bytes32[](n);
        bytes32[] memory prof = new bytes32[](n);

        uint32 j = 0;
        uint32 i = start;
        for (; i < orgsList.length && j < n; i++) {
            bytes32 org = orgsList[i];
            if (orgs[org].meta["suspended"] != 0) {
                continue;
            }
            res[j] = org;
            prof[j] = orgs[org].meta["profile"];

            j++;
        }

        if (j < n) {
            bytes32[] memory q = new bytes32[](j);
            bytes32[] memory w = new bytes32[](j);
            for (uint256 ii = 0; ii < j; ii++) {
                q[ii] = res[ii];
                w[ii] = prof[ii];
            }
            res = q;
            prof = w;
        }

        if (i == orgsList.length) {
            i = 0;
        }

        return (res, prof, i);
    }

    function checkorgf(bytes32 org) internal view {
        Org storage o = orgs[org];

        require(o.id == org, "no such org");
        require(
            isAdmin(msg.sender) || o.meta["suspended"] == 0,
            "org suspended"
        );
        require(
            isAdmin(msg.sender) || isParentRobot(org, msg.sender),
            "admin or robot required"
        );
    }

    modifier checkorg(bytes32 org) {
        checkorgf(org);

        _;
    }

    modifier allowed() {
        require(successor == 0, "contract upgraded");

        checkorgf(orgsByRobot[msg.sender]);

        _;
    }

    modifier checkuserid(bytes32 id) {
        User storage u = users[id];

        require(u.id == id, "no such user");

        checkorgf(u.org);

        _;
    }
}

contract Docs is Orgs {
    event DocCreated(bytes32 indexed docid, address indexed robot);
    event DocPublished(bytes32 indexed org, bytes32 indexed docid);

    struct Doc {
        bytes32 id;
        bytes32[] parties;
    }

    mapping(bytes32 => Doc) public docs;
    mapping(bytes32 => bytes32[]) public docsByParty; // party => docs id list
    mapping(bytes32 => bytes32) public exclusive; // tag => doc - forces to have only one doc with each given tag

    function setOrgMetaDoc(
        bytes32 org,
        bytes32 k,
        bytes32 docid,
        bytes32[] parties,
        bytes32[] tags
    ) external {
        createDoc(docid, parties, tags);

        setOrgMeta(org, k, docid);
    }

    function casOrgMetaDoc(
        bytes32 org,
        bytes32 k,
        bytes32 old,
        bytes32 docid,
        bytes32[] parties,
        bytes32[] tags
    ) external {
        createDoc(docid, parties, tags);

        casOrgMeta(org, k, old, docid);
    }

    function setUserMetaDoc(
        bytes32 userid,
        bytes32 k,
        bytes32 docid,
        bytes32[] parties,
        bytes32[] tags
    ) external {
        createDoc(docid, parties, tags);

        setUserMeta(userid, k, docid);
    }

    function casUserMetaDoc(
        bytes32 userid,
        bytes32 k,
        bytes32 old,
        bytes32 docid,
        bytes32[] parties,
        bytes32[] tags
    ) external {
        createDoc(docid, parties, tags);

        casUserMeta(userid, k, old, docid);
    }

    function createDoc(
        bytes32 docid,
        bytes32[] memory parties,
        bytes32[] memory tags
    ) public allowed {
        require(docid != 0, "zero docid");
        require(docs[docid].id == "", "duplicated doc");
        require(parties.length != 0, "no parties");

        for (uint256 pp = 0; pp < parties.length; pp++) {
            require(parties[pp] != 0, "empty party");
        }

        for (uint256 tt = 0; tt < tags.length; tt++) {
            require(exclusive[tags[tt]] == 0, "not exclusive");

            exclusive[tags[tt]] = docid;
        }

        docs[docid] = Doc({id: docid, parties: parties});

        emit DocCreated(docid, msg.sender);

        for (uint256 i = 0; i < parties.length; i++) {
            emit DocPublished(parties[i], docid);
        }
    }

    function publishDoc(bytes32 docid, bytes32[] parties) external allowed {
        Doc storage d = docs[docid];

        require(d.id == docid, "no such doc");

        bytes32 org = orgsByRobot[msg.sender];

        require(isDocParty(docid, org), "not allowed");

        for (uint256 i = 0; i < parties.length; i++) {
            bytes32 p = parties[i];

            for (uint256 j = 0; j < d.parties.length; j++) {
                require(d.parties[j] != p, "duplicated party");
            }

            d.parties.push(p);

            emit DocPublished(p, docid);
        }
    }

    function isDocParty(bytes32 docid, bytes32 party)
        public
        view
        returns (bool)
    {
        Doc storage d = docs[docid];

        for (uint256 i = 0; i < d.parties.length; i++) {
            if (d.parties[i] == party) {
                return true;
            }
        }

        return false;
    }

    function docParties(bytes32 docid) external view returns (bytes32[]) {
        Doc storage d = docs[docid];

        return d.parties;
    }

    function docCanBeRead(bytes32 docid, address addr)
        external
        view
        returns (bool, bytes32)
    {
        Org storage rorg = orgs[orgsByRobot[addr]];
        if (rorg.id == "") {
            return (false, "not org robot");
        }
        if (rorg.meta["suspended"] != 0) {
            return (false, "org suspended");
        }

        Docs ct = this;
        bytes32 id = ct.docs(docid);

        while (id == "") {
            if (ct.predecessor() == 0) {
                return (false, "no such doc");
            }

            ct = Docs(ct.predecessor());

            id = ct.docs(docid);
        }

        bytes32[] memory parties = ct.docParties(docid);

        for (uint256 i = 0; i < parties.length; i++) {
            bytes32 org = parties[i];

            if (org == "public") {
                return (true, "public");
            }

            Org storage o = orgs[org];

            if (o.id != org) {
                // do not exists
                continue;
            }

            if (isRobot(org, addr)) {
                return (true, "org robot");
            }

            bytes32 par = o.meta["parent"];
            if (isParentRobot(par, addr)) {
                return (true, "parent org");
            }
        }

        return (false, "no reasons");
    }

    function checkExclusive(bytes32[] tags) external view returns (bytes32) {
        for (uint256 tt = 0; tt < tags.length; tt++) {
            if (exclusive[tags[tt]] == 0) {
                continue;
            }

            return exclusive[tags[tt]];
        }

        return 0;
    }
}

contract TF is Docs {
    event TFCreated(
        address indexed creator,
        bytes32 indexed ver,
        address indexed pred
    );

    constructor(address pred) public Admined(pred) {
        emit TFCreated(msg.sender, VERSION, pred);
    }
}
