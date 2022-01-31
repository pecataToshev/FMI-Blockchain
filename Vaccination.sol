// SPDX-License-Identifier: GPL-3.0

pragma solidity >= 0.7.0;


contract VaccinateDb {

    address public authority;
    mapping (address => bool) public vaccinationCenter;
    mapping (address => Vaccine) public vaccinateHistory;

    struct Vaccine {
        uint vacineId;
        address vaccinationCenter;
    }

    event AddVacinationCenter(address vaccinationCenter);
    event Vaccinate(address receiver, address vaccinationCenter, uint sertificateId);

    constructor() {
        authority = msg.sender;
    }

    function vaccinate(address receiver, uint sertificateId) public {

        require(vaccinationCenter[msg.sender] == true, "Unknown vaccination center");
        vaccinateHistory[receiver] = Vaccine(sertificateId, msg.sender);
        emit Vaccinate(receiver, msg.sender, sertificateId);
    }

    function addVaccinationCenter(address center) public {
        require(msg.sender == authority, "Unknown authority");
        vaccinationCenter[center] = true;
        emit AddVacinationCenter(center);
    }

}

