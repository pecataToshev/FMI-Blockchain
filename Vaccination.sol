// SPDX-License-Identifier: GPL-3.0

pragma solidity >= 0.7.0;

import "hardhat/console.sol";

uint constant SECONDS_IN_A_DAY = 60 * 60 * 24;

struct VaccinationRecord  {
    string vaccine;
    uint256 timestamp;
}

struct PatientRecord {
    string name;
    bool hasRequestedVaccination;
    VaccinationRecord[] records;
}

struct VaccineData {
    string name;
    uint[] minimumDaysAfterPrevious;
}

struct Statistics {
    uint totalNumberVaccineShots;
    uint totalNumberVaccinatedPeople;
    mapping (uint => uint) vaccineShotsByDay;
}

contract VaccineRegistry {

    address public trustedAuthority;
    uint public certificateValidityInDays;

    mapping (string => VaccineData) public approvedVaccines;
    mapping (address => bool) public vaccinationCenters;
    mapping (address => PatientRecord) public patientRecords;

    Statistics stats;

    constructor(uint _certificateValidityInDays) {
        trustedAuthority = msg.sender;
        certificateValidityInDays = _certificateValidityInDays;
        addVaccine("a");
        addVaccine("b");
        addVaccine("c");
    }

    function register(string memory name) public {
        require(!isRegistered(msg.sender), "Already registered!");
        patientRecords[msg.sender].name = name;
    }

    function requestVaccination() public {
        requirePatientRegistered(msg.sender);
        require(!patientRecords[msg.sender].hasRequestedVaccination, "Already requested!");
        requirePatientEligibleForVaccination(msg.sender);
        patientRecords[msg.sender].hasRequestedVaccination = true;
    }

    function vaccinate(address patient, string memory vaccineName) public payable {
        require(vaccinationCenters[msg.sender], "Unauthorized vaccination center!");
        requireVaccineIsApproved(vaccineName);
        requirePatientRegistered(patient);
        require(patientRecords[patient].hasRequestedVaccination , "Patient has not requested a vaccine!");
        requirePatientEligibleForVaccination(patient);
        
        patientRecords[patient].records.push(VaccinationRecord(vaccineName, block.timestamp));
        patientRecords[patient].hasRequestedVaccination = false;
        
        updateStatistics(patient);
    }

    function changeCertificateValidityInDays(uint newCertificateValidityInDays) public {
        requireAuthority();
        certificateValidityInDays = newCertificateValidityInDays;
    }
    
    function addVaccinationCenter(address center) public {
        requireAuthority();
        vaccinationCenters[center] = true;
    }

    function addVaccine(string memory vaccineName) public {
        requireAuthority();
        approvedVaccines[vaccineName].name = vaccineName;
        approvedVaccines[vaccineName].minimumDaysAfterPrevious.push(0);
    }

    function addNextMinimumDaysAfterPreviousDoseToVaccine(string memory vaccineName, uint minimumDays) public {
        requireAuthority();
        requireVaccineIsApproved(vaccineName);
        approvedVaccines[vaccineName].minimumDaysAfterPrevious.push(minimumDays);
    }

    function isWithValidCertificate(address person) public view returns (bool) {
        if (!isRegistered(person)) return false;
        uint doses = getNumberOfDoses(person);
        if (doses == 0) return false;

        uint diff = block.timestamp - patientRecords[person].records[doses - 1].timestamp;
        return convertDaysToSeconds(certificateValidityInDays) > diff;
    }

    function getTotalNumberVaccineShots() public view returns (uint256) {
        return stats.totalNumberVaccineShots;
    }

    function getTotalNumberVaccinatedPeople() public view returns (uint256) {
        return stats.totalNumberVaccinatedPeople;
    }

    function getVaccineShotsLastWeekByDay() public view returns (uint[] memory) {
        uint currentDay = convertSecondsToDays(block.timestamp);
        uint[] memory lastWeekVaccineShotByDay = new uint[](7);
        for(uint i = 0; i < 7; i++) {
            lastWeekVaccineShotByDay[i] = stats.vaccineShotsByDay[currentDay - i];
        }
        return lastWeekVaccineShotByDay;
    }

    function getRemainingDaysUntilNextDose(address patient) public view returns (uint) {
        uint doses = getNumberOfDoses(patient);
        if (doses == 0) {
            return 0;
        }

        VaccinationRecord memory lastRecord = patientRecords[patient].records[doses - 1];

        requireVaccineIntervalPresent(lastRecord.vaccine, doses);

        uint minimumDays = approvedVaccines[lastRecord.vaccine].minimumDaysAfterPrevious[doses];
        uint diff = block.timestamp - lastRecord.timestamp;
        uint minimumDaysSeconds = convertDaysToSeconds(minimumDays);
        if (minimumDaysSeconds <= diff) {
            return 0;
        }

        return convertSecondsToDays(minimumDaysSeconds - diff + SECONDS_IN_A_DAY - 1);
    }

    function requireAuthority() private view {
        require(msg.sender == trustedAuthority, "Sender is not trusted authority!");
    }

    function requireVaccineIsApproved(string memory vaccineName) private view {
        require(isVaccineApproved(vaccineName), "Unapproved vaccine!");
    }

    function requirePatientRegistered(address patient) private view {
        require(isRegistered(patient), "Patient not registered!");
    }

    function requireVaccineIntervalPresent(string memory vaccineName, uint dose) private view {
        require(approvedVaccines[vaccineName].minimumDaysAfterPrevious.length > dose, "Information for dose is missing");
    }

    function requirePatientEligibleForVaccination(address patient) private view {
        require(patientEligibleForVaccination(patient), "Patient is not eligible for vaccination!");
    }

    function patientEligibleForVaccination(address patient) private view returns (bool) {
        uint doses = getNumberOfDoses(patient);
        if (doses == 0) {
            return true;
        }

        VaccinationRecord memory lastRecord = patientRecords[patient].records[doses - 1];

        requireVaccineIntervalPresent(lastRecord.vaccine, doses);

        uint minimumDays = approvedVaccines[lastRecord.vaccine].minimumDaysAfterPrevious[doses];
        uint diff = block.timestamp - lastRecord.timestamp;
        return convertDaysToSeconds(minimumDays) <= diff;
    }

    function getNumberOfDoses(address patient) private view returns (uint) {
        return patientRecords[patient].records.length;
    }

    function convertDaysToSeconds(uint _days) private pure returns (uint) {
        return _days * SECONDS_IN_A_DAY;
    }

    function convertSecondsToDays(uint _seconds) private pure returns (uint) {
        return _seconds / SECONDS_IN_A_DAY; 
    }

    function isVaccineApproved(string memory name) private view returns (bool) {
        return !isBlank(approvedVaccines[name].name);
    }

    function isRegistered(address patient) private view returns (bool) {
        return !isBlank(patientRecords[patient].name);
    }

    function isBlank(string memory a) private pure returns (bool) {
        return bytes(a).length == 0;
    }

    function updateStatistics(address patient) private {
        increaseTotalVaccineShots();
        increaseTotalVaccinatedPeople(patient);
        uint currentDay = convertSecondsToDays(block.timestamp);
        stats.vaccineShotsByDay[currentDay]++;
    }

    function increaseTotalVaccineShots() private {
        stats.totalNumberVaccineShots++;
    }

    function increaseTotalVaccinatedPeople(address patient) private {
        if (patientRecords[patient].records.length == 1) {
            stats.totalNumberVaccinatedPeople++;
        }
    }
}
