/**
  Copyright (C) 2026 by Lars Kool, Plateforme Technologique
  All rights reserved.

  Post processor configuration for Probylas laser cutting.

  FORKID {0A45B7F8-16FA-450B-AB4F-0E1BC1A65FAA}
*/

description = "Probylas Laser";
vendor = "IPGG";
vendorUrl = "https://github.com/Lars-Kool/Probylas_Turnkey_post";
legal = "Copyright (C) 2026 by Plateforme Technologique. All rights reserved.";
certificationLevel = 2;
minimumRevision = 45702;

longDescription = "Post for Probylas laser cutting.";

extension = "nc";
setCodePage("ascii");

capabilities = CAPABILITY_JET;
tolerance = spatial(0.001, MM);

minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = false;
allowedCircularPlanes = undefined; // allow any circular motion

var parameters = {};

// user-defined properties
properties = {
  xOffset: {
    title      : "X Offset",
    description: "Sets the X offset for the workpiece in mm.",
    group      : "preferences",
    type       : "number",
    value      : 0,
    scope      : "post"
  },
  yOffset: {
    title      : "Y Offset",
    description: "Sets the Y offset for the workpiece in mm.",
    group      : "preferences",
    type       : "number",
    value      : 0,
    scope      : "post"
  },
  zOffset: {
    title      : "Z Offset",
    description: "Sets the Z offset for the workpiece in mm.",
    group      : "preferences",
    type       : "number",
    value      : 0,
    scope      : "post"
  },
  setLaserPower: {
    title      : "Use Post processor laser powers",
    description: "If enabled, the laser power will be set at the beginning of each section according to the cutting mode. If disabled, the laser power will not be set and must be set manually using the Probylas software.",
    group      : "preferences",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  laserPowerAuto: {
    title      : "Laser Power: Auto",
    description: "Sets the laser power (S) for cutting. The value is in the range 0-30 W (0.1 W steps).",
    group      : "preferences",
    type       : "number",
    value      : 5,
    scope      : "post"
  },
  laserPowerHQ : {
    title      : "Laser Power: High Quality",
    description: "Sets the laser power (S) for cutting. The value is in the range 0-30 W (0.1 W steps).",
    group      : "preferences",
    type       : "number",
    value      : 5,
    scope      : "post"
  },
  laserPowerMQ : {
    title      : "Laser Power: Medium Quality",
    description: "Sets the laser power (S) for cutting. The value is in the range 0-30 W (0.1 W steps).",
    group      : "preferences",
    type       : "number",
    value      : 5,
    scope      : "post"
  },
  laserPowerLQ : {
    title      : "Laser Power: Low Quality",
    description: "Sets the laser power (S) for cutting. The value is in the range 0-30 W (0.1 W steps).",
    group      : "preferences",
    type       : "number",
    value      : 5,
    scope      : "post"
  },
  laserPowerVap : {
    title      : "Laser Power: Vaporize",
    description: "Sets the laser power (S) for cutting. The value is in the range 0-30 W (0.1 W steps).",
    group      : "preferences",
    type       : "number",
    value      : 5,
    scope      : "post"
  },
  laserPowerEtch : {
    title      : "Laser Power: Etch",
    description: "Sets the laser power (S) for cutting. The value is in the range 0-30 W (0.1 W steps).",
    group      : "preferences",
    type       : "number",
    value      : 5,
    scope      : "post"
  },
  dwellTime: {
    title      : "Dwell Time",
    description: "Sets the dwell time (P) for cutting. The value is in the range 0.001-99.999 seconds.",
    group      : "preferences",
    type       : "number",
    value      : 0.1,
    scope      : "post"
  }
};

// wcs definiton
wcsDefinitions = {
  useZeroOffset: true,
  wcs          : [
    {name:"Standard", format:"G", range:[54, 59]}
  ]
};

var gFormat = createFormat({prefix:"G", decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4)});
var feedFormat = createFormat({decimals:(unit == MM ? 1 : 2)});
var toolFormat = createFormat({decimals:0});
var powerFormat = createFormat({decimals:1});
var secFormat = createFormat({decimals:3, forceDecimal:true}); // seconds - range 0.001-1000

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({prefix:"Z"}, xyzFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var sOutput = createVariable({prefix:"S", force:true}, powerFormat);
var dwellOutput = createVariable({prefix:"P", force:true}, secFormat);

// circular output
var iOutput = createVariable({prefix:"I"}, xyzFormat);
var jOutput = createVariable({prefix:"J"}, xyzFormat);

var gMotionModal = createModal({force:true}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createModal({onchange:function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gFeedModeModal = createModal({}, gFormat); // modal group 5 // G93-94
var gUnitModal = createModal({}, gFormat); // modal group 6 // G20-21
var gDwellModal = createModal({}, gFormat, dwellOutput); // modal group 8 // G4

var WARNING_WORK_OFFSET = 0;
var isSpotWeld = false;

/**
  Writes the specified block.
*/
function writeBlock() {
  writeWords(arguments);
}

function formatComment(text) {
  return "(" + String(text).replace(/[()]/g, "") + ")";
}

/**
  Output a comment.
*/
function writeComment(text) {
  writeln(formatComment(text));
}

/**
 * Runs on opening the post processor. Initializes the post processor state and outputs the header.
 */
function onOpen() {
  // Make sure laser is off
  writeBlock(mFormat.format(11));
  // Activate the zero point of the coordinate system (center of workpiece).
  writeBlock(gUnitModal.format(54));
  // Shifts the zero point of the coordinate system to put the contours in the center of the workpiece.
  writeBlock(gUnitModal.format(58), xOutput.format(getProperty("xOffset")), yOutput.format(getProperty("yOffset")));

  // Set focus (Z offset)
  writeBlock(gMotionModal.format(0), zOutput.format(getProperty("zOffset")));
}

function onComment(message) {
  writeComment(message);
}

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  // zOutput.reset();
}

/** Force output of X, Y, Z, and F on next output. */
function forceAny() {
  forceXYZ();
  feedOutput.reset();
}

function onSection() {

  writeln("");

  if (currentSection.getType() != TYPE_JET) {
    error(localize("The CNC does not support the required tool/process. Only laser cutting is supported."));
    return;
  }
  if (tool.type != TOOL_LASER_CUTTER) {
    error(localize("The CNC does not support the required tool/process. Only laser cutting is supported."));
    return;
  }

  writeComment(currentSection.getParameter("operation-comment"));
  isSpotWeld = (currentSection.getParameter("operation-comment") == "spotweld");

  var remaining = currentSection.workPlane;
  if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
    error(localize("Tool orientation is not supported."));
    return;
  }
  setRotation(remaining);

  if (getProperty("setLaserPower")) {
    var power = getLaserPower();
    writeBlock(gMotionModal.format(0), sOutput.format(power));
  }

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  writeBlock(gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y));
}

function onDwell(seconds) {
  if (seconds > 99.999) {
    warning(localize("Dwelling time is out of range."));
  }
  seconds = clamp(0.001, seconds, 99.999);
  writeBlock(gFormat.format(4), "P" + secFormat.format(seconds));
}

var pendingRadiusCompensation = -1;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

function onPower(power) {
}

function onRapid(_x, _y, _z) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  if (x || y) {
    if (pendingRadiusCompensation >= 0) {
      error(localize("Radius compensation mode cannot be changed at rapid traversal."));
      return;
    }
    writeBlock(gMotionModal.format(0), x, y);
    feedOutput.reset();
  }
}

function onLinear(_x, _y, _z, feed) {
  // at least one axis is required
  if (pendingRadiusCompensation >= 0) {
    // ensure that we end at desired position when compensation is turned off
    xOutput.reset();
    yOutput.reset();
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var f = feedOutput.format(feed / 60);
  if (x || y) {
    if (pendingRadiusCompensation >= 0) {
      error(localize("Radius compensation mode is not supported."));
      return;
    } else {
      writeBlock(gMotionModal.format(1), x, y, f);
    }
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      feedOutput.reset(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(1), f);
    }
  }

  if (isSpotWeld) {
    writeBlock(mFormat.format(10)); // Laser on
    onDwell(getProperty("dwellTime"));
    writeBlock(mFormat.format(11)); // Laser off
    writeln("");
  }
}

function onRapid5D(_x, _y, _z, _a, _b, _c) {
  error(localize("The CNC does not support 5-axis simultaneous toolpath."));
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  error(localize("The CNC does not support 5-axis simultaneous toolpath."));
}

function forceCircular(plane) {
  switch (plane) {
  case PLANE_XY:
    xOutput.reset();
    yOutput.reset();
    iOutput.reset();
    jOutput.reset();
    break;
  case PLANE_ZX:
    error(localize("Circular motion in the ZX plane is not supported."));
    break;
  case PLANE_YZ:
    error(localize("Circular motion in the YZ plane is not supported."));
    break;
  default:
    error(localize("Circular motion in the specified plane is not supported."));
    break;
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (getCircularPlane() != PLANE_XY) {
    error(localize("Only circular motion in the XY plane is supported."));
    return;
  }
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for a circular move."));
    return;
  }

  var start = getCurrentPosition();
  if (isFullCircle() && isHelical()) {
    linearize(tolerance);
  }
  forceCircular(getCircularPlane());
  writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), iOutput.format(cx - start.x),
    jOutput.format(cy - start.y), feedOutput.format(feed / 60)
  );
}

/**
 * No M-code commands are supported, so this function does nothing.
 * @param command 
 */
function onCommand(command) {
}

function onSectionEnd() {
  forceAny();
}

// Handles laser power whenever movement type changes
function onMovement(movement) {
  switch (movement) {
    case MOVEMENT_CUTTING: {
      writeBlock(mFormat.format(10)); // Laser on
      break;
    }
    case MOVEMENT_LEAD_OUT: {
      writeBlock(mFormat.format(11)); // Laser off
      break;
    }
    default: {
      break;
    }
  }
}

/**
 * Runs on closing the post processor. Outputs the footer and cleans up the post processor state.
 * No need to do anything here, as the laser is turned off before the lead-out.
 */
function onClose() {
}

function setProperty(property, value) {
  properties[property].current = value;
}

function getLaserPower() {
  var cuttingMode = parameters["operation:cuttingMode"];
  switch (cuttingMode) {
    case "auto":
      return getProperty("laserPowerAuto");
    case "fast cut":
      return getProperty("laserPowerLQ");
    case "medium cut":
      return getProperty("laserPowerMQ");
    case "slow cut":
      return getProperty("laserPowerHQ");
    case "vaporize":
      return getProperty("laserPowerVap");
    case "etch":
      return getProperty("laserPowerEtch");
    default:
      return 0;
  }
}

function onParameter(name, value) {
  parameters[name] = value;
  // writeComment(name + "=" + value);
}